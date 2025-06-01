import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import para RepeatInterval
import '../models/reminder.dart';
import '../database/category_helper.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
// import '../screens/reminders_list.dart'; // REMOVIDO - unused_import
// import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // REMOVIDO - unused_import

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminderToEdit;

  const AddReminderScreen({super.key, this.reminderToEdit});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newCategoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'Adicione as categorias aqui';
  late DateTime _selectedDateTime;
  bool _isRecurring = false;

  List<Map<String, dynamic>> _categories = [];
  final CategoryHelper _categoryHelper = CategoryHelper();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  bool _isLoadingCategories = true;
  bool _isSaving = false;
  bool _isCreatingCategory = false;

  Color _selectedNewCategoryColor = Colors.grey;
  final List<Color> _predefinedColors = [
    Colors.blue, Colors.green, Colors.red, Colors.orange, Colors.purple,
    Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan,
    Colors.brown, Colors.grey,
  ];

  bool get _isEditing => widget.reminderToEdit != null;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = _isEditing ? widget.reminderToEdit!.dateTime : DateTime.now();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadCategories();
    if (_isEditing) {
      _populateEditingData();
    }
  }

  void _populateEditingData() {
    final reminder = widget.reminderToEdit!;
    _titleController.text = reminder.title;
    _descriptionController.text = reminder.description;
    _selectedCategory = reminder.category;
    _isRecurring = reminder.isRecurring;
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      await _categoryHelper.ensureDefaultCategory();
      await Future.delayed(const Duration(milliseconds: 100));
      final categories = await _categoryHelper.getAllCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        if (categories.isNotEmpty) {
          final categoryNames = categories.map((c) => c['name'] as String).toList();
          if (_isEditing && categoryNames.contains(widget.reminderToEdit!.category)) {
             _selectedCategory = widget.reminderToEdit!.category;
          } else if (!categoryNames.contains(_selectedCategory) || _selectedCategory == 'Adicione as categorias aqui') {
             _selectedCategory = categoryNames.first;
          }
        } else {
          _selectedCategory = 'Adicione as categorias aqui';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        _categories = [];
        _selectedCategory = 'Adicione as categorias aqui';
      });
      _showMessage('Erro ao carregar categorias', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar Lembrete' : 'Novo Lembrete',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isSaving ? _buildLoadingOverlay() : _buildMainContent(),
    );
  }

  Widget _buildLoadingOverlay() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      // CORREÇÃO: Usar colorScheme.scrim ou similar para overlay
      color: colorScheme.scrim.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(50),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                _isEditing ? 'Atualizando lembrete...' : 'Salvando lembrete...',
                style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSimpleCard(
            icon: Icons.title,
            title: 'Título',
            child: TextFormField(
              controller: _titleController,
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Digite um título';
                }
                if (value.trim().length > 100) {
                  return 'Título muito longo (máx. 100 caracteres)';
                }
                return null;
              },
              decoration: const InputDecoration(
                hintText: 'Digite o título do lembrete',
                border: InputBorder.none,
                counterText: '',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 16),
          _buildSimpleCard(
            icon: Icons.description,
            title: 'Descrição',
            child: TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 500,
              validator: (value) {
                if (value != null && value.trim().length > 500) {
                  return 'Descrição muito longa (máx. 500 caracteres)';
                }
                return null;
              },
              decoration: const InputDecoration(
                hintText: 'Digite uma descrição (opcional)',
                border: InputBorder.none,
                counterText: '',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryCard(),
          const SizedBox(height: 16),
          _buildRecurringCard(),
          const SizedBox(height: 16),
          _buildDateCard(),
          const SizedBox(height: 16),
          _buildTimeCard(),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSimpleCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Categoria',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_isCreatingCategory)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                )
              else
                IconButton(
                  onPressed: _showAddCategoryDialog,
                  icon: Icon(Icons.add, color: colorScheme.primary),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingCategories
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary),
                        const SizedBox(height: 8),
                        Text('Carregando categorias...', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              : _buildCategoryDropdown(),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_categories.isEmpty) {
      return Text(
        'Nenhuma categoria encontrada. Adicione uma clicando no +.',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }

    final categoryNames = _categories.map((c) => c['name'] as String).toList();
    // Garante que _selectedCategory seja válido ou o primeiro da lista
    if (!categoryNames.contains(_selectedCategory) || _selectedCategory == 'Adicione as categorias aqui') {
       _selectedCategory = categoryNames.first;
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      style: TextStyle(color: colorScheme.onSurface),
      // CORREÇÃO: Usar colorScheme.surfaceContainerHighest
      dropdownColor: colorScheme.surfaceContainerHighest,
      decoration: const InputDecoration(border: InputBorder.none),
      items: _categories.map((category) {
        final name = category['name'] as String;
        final colorHex = category['color'] as String;
        Color color = Colors.grey;
        try {
          // Tenta parsear como ARGB (padrão do Color.value)
          color = Color(int.parse(colorHex, radix: 16));
        } catch (e) {
          debugPrint('Erro ao parsear cor $colorHex para categoria $name no dropdown: $e');
          // Tenta parsear como #RRGGBB (se for o caso)
          try {
             if (colorHex.startsWith('#') && colorHex.length == 7) {
               color = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
             }
          } catch (e2) {
             debugPrint('Erro ao parsear cor $colorHex como #RRGGBB: $e2');
          }
        }

        return DropdownMenuItem(
          value: name,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(name),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCategory = value);
        }
      },
    );
  }

  Widget _buildRecurringCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.repeat, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Repetir Mensalmente',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Switch(
            value: _isRecurring,
            onChanged: (value) => setState(() => _isRecurring = value),
            activeColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.onSurface.withOpacity(0.38),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Data',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('dd/MM/yyyy').format(_selectedDateTime),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Horário',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _selectTime,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('HH:mm').format(_selectedDateTime),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveReminder,
      icon: Icon(Icons.save, color: colorScheme.onPrimary),
      label: Text(
        _isEditing ? 'Atualizar Lembrete' : 'Salvar Lembrete',
        style: TextStyle(color: colorScheme.onPrimary, fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        final currentTheme = Theme.of(context);
        return Theme(
          data: currentTheme.copyWith(
            colorScheme: currentTheme.colorScheme.copyWith(
              primary: currentTheme.colorScheme.primary,
              onPrimary: currentTheme.colorScheme.onPrimary,
              surface: currentTheme.colorScheme.surface,
              onSurface: currentTheme.colorScheme.onSurface,
            ),
            // CORREÇÃO: Passar DialogThemeData diretamente
            dialogTheme: currentTheme.dialogTheme.copyWith(
              backgroundColor: currentTheme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: currentTheme.colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateTime) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        final currentTheme = Theme.of(context);
        return Theme(
          data: currentTheme.copyWith(
            colorScheme: currentTheme.colorScheme.copyWith(
              primary: currentTheme.colorScheme.primary,
              onPrimary: currentTheme.colorScheme.onPrimary,
              surface: currentTheme.colorScheme.surface,
              onSurface: currentTheme.colorScheme.onSurface,
            ),
            // CORREÇÃO: Passar DialogThemeData diretamente
            dialogTheme: currentTheme.dialogTheme.copyWith(
              backgroundColor: currentTheme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            timePickerTheme: currentTheme.timePickerTheme.copyWith(
              backgroundColor: currentTheme.colorScheme.surface,
              hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              dayPeriodShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _showAddCategoryDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    _selectedNewCategoryColor = _predefinedColors.first;
    _newCategoryController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              title: Text('Nova Categoria', style: TextStyle(color: colorScheme.onSurface)),
              content: SingleChildScrollView( // Adicionado para evitar overflow com ColorPicker
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _newCategoryController,
                      maxLength: 50,
                      decoration: InputDecoration(
                        hintText: 'Nome da categoria',
                        counterText: '',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 20),
                    Text('Escolha uma cor:', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _predefinedColors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              _selectedNewCategoryColor = color;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedNewCategoryColor == color
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: colorScheme.secondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = _newCategoryController.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.pop(context);
                      await _addCategory(name, _selectedNewCategoryColor);
                    } else {
                      // TODO: Mostrar erro de nome vazio
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary),
                  child: Text('Adicionar', style: TextStyle(color: colorScheme.onPrimary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addCategory(String name, Color color) async {
    if (!mounted) return;
    setState(() => _isCreatingCategory = true);
    try {
      // CORREÇÃO: Usar .value que retorna int ARGB, e converter para String Hexadecimal (sem alpha)
      String colorHex = '#${color.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';

      await _categoryHelper.addCategory(name, colorHex);
      await _loadCategories();
      if (mounted) {
        setState(() {
          _selectedCategory = name;
          _isCreatingCategory = false;
        });
        _showMessage('Categoria "$name" adicionada!', Colors.green);
      }
    } catch (e) {
      debugPrint('Erro ao adicionar categoria: $e');
      if (mounted) {
        setState(() => _isCreatingCategory = false);
        _showMessage('Erro ao adicionar categoria', Colors.red);
      }
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Por favor, corrija os erros no formulário.', Colors.orange);
      return;
    }

    if (_selectedCategory == 'Adicione as categorias aqui' || _categories.where((c) => c['name'] == _selectedCategory).isEmpty) {
      _showMessage('Por favor, selecione ou adicione uma categoria válida.', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final finalDateTime = _selectedDateTime;

    if (finalDateTime.isBefore(now)) {
       debugPrint("Aviso: Data/hora selecionada ($finalDateTime) está no passado. Notificação não será agendada.");
    }

    final reminder = Reminder(
      id: _isEditing ? widget.reminderToEdit!.id : null,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      dateTime: finalDateTime,
      isCompleted: _isEditing ? widget.reminderToEdit!.isCompleted : false,
      isRecurring: _isRecurring,
      recurringType: _isRecurring ? 'monthly' : null,
      notificationsEnabled: _isEditing ? widget.reminderToEdit!.notificationsEnabled : true,
    );

    try {
      int? savedId = reminder.id;
      if (_isEditing) {
        await _databaseHelper.updateReminder(reminder);
      } else {
        savedId = await _databaseHelper.insertReminder(reminder);
        reminder.id = savedId;
      }

      if (savedId != null) {
        await NotificationService.cancelNotification(savedId);
        // Apenas agenda se habilitado E data/hora não estiver muito no passado
        if (reminder.notificationsEnabled && finalDateTime.isAfter(now.subtract(const Duration(seconds: 5)))) {
          if (reminder.isRecurring) {
            // A lógica de recorrência mensal precisa ser implementada corretamente.
            // O NotificationService atual não suporta RepeatInterval.monthly.
            // Por enquanto, agendaremos apenas a próxima ocorrência.
            DateTime nextOccurrence = reminder.getNextOccurrence();
            debugPrint("Agendando notificação recorrente (próxima ocorrência) para: $nextOccurrence");
            await NotificationService.scheduleNotification(
              id: savedId,
              title: "(Recorrente) ${reminder.title}",
              description: reminder.description,
              scheduledDate: nextOccurrence,
              category: reminder.category,
            );
            // Nota: O app precisaria reagendar a notificação após ela disparar.
          } else {
            await NotificationService.scheduleNotification(
              id: savedId,
              title: reminder.title,
              description: reminder.description,
              scheduledDate: reminder.dateTime,
              category: reminder.category,
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, reminder); // Retorna o lembrete salvo/atualizado
      }

    } catch (e) {
      debugPrint('❌ Erro ao salvar lembrete: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showMessage('Erro ao salvar lembrete', Colors.red);
      }
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }
}

