import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../database/category_helper.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../screens/reminders_list.dart'; // Import para navegação

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
  // ✅ CORREÇÃO: Usar uma única variável DateTime para data e hora
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
    // ✅ CORREÇÃO: Inicializar _selectedDateTime
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
    // ✅ CORREÇÃO: _selectedDateTime já foi inicializado no initState
    // _selectedDateTime = reminder.dateTime;
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
          } else if (!categoryNames.contains(_selectedCategory)) {
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
      backgroundColor: colorScheme.surface, // Corrigido de background
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
      color: Colors.black.withOpacity(0.5),
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
        'Nenhuma categoria encontrada',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }

    final categoryNames = _categories.map((c) => c['name'] as String).toList();
    if (!categoryNames.contains(_selectedCategory)) {
       _selectedCategory = categoryNames.isNotEmpty ? categoryNames.first : 'Adicione as categorias aqui';
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      style: TextStyle(color: colorScheme.onSurface),
      dropdownColor: colorScheme.surfaceVariant,
      decoration: const InputDecoration(border: InputBorder.none),
      items: _categories.map((category) {
        final name = category['name'] as String;
        final colorHex = category['color'] as String;
        Color color = Colors.grey;
        try {
          color = Color(int.parse(colorHex, radix: 16));
        } catch (e) {
          debugPrint('Erro ao parsear cor $colorHex para categoria $name no dropdown: $e');
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
                // ✅ CORREÇÃO: Usar _selectedDateTime para formatar
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
                // ✅ CORREÇÃO: Usar _selectedDateTime para formatar
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
      onPressed: _saveReminder,
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
      // ✅ CORREÇÃO: Usar _selectedDateTime
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            dialogBackgroundColor: theme.dialogBackgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // ✅ CORREÇÃO: Atualizar _selectedDateTime mantendo a hora
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
      // ✅ CORREÇÃO: Usar _selectedDateTime
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            dialogBackgroundColor: theme.dialogBackgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // ✅ CORREÇÃO: Atualizar _selectedDateTime mantendo a data
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
    _newCategoryController.clear();
    _selectedNewCategoryColor = Colors.grey;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.dialogBackgroundColor,
            title: Text('Nova Categoria', style: TextStyle(color: colorScheme.onSurface)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _newCategoryController,
                    autofocus: true,
                    maxLength: 50,
                    decoration: InputDecoration(
                      hintText: 'Nome da categoria',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      counterText: '',
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
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
                      bool isSelected = _selectedNewCategoryColor == color;
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
                            border: isSelected
                                ? Border.all(color: colorScheme.onSurface, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.5),
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : [],
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
              TextButton(
                onPressed: () => _addCategory(_selectedNewCategoryColor),
                child: Text('Adicionar', style: TextStyle(color: colorScheme.primary)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addCategory(Color selectedColor) async {
    final categoryName = _newCategoryController.text.trim();
    if (categoryName.isEmpty) {
      _showMessage('Nome da categoria não pode ser vazio', Colors.orange);
      return;
    }
    if (categoryName.length > 50) {
      _showMessage('Nome da categoria muito longo (máx. 50)', Colors.orange);
      return;
    }

    Navigator.pop(context); // Fecha o diálogo antes de tentar salvar
    setState(() => _isCreatingCategory = true);

    try {
      final colorHex = selectedColor.value.toRadixString(16);
      await _categoryHelper.addCategory(categoryName, colorHex);
      await _loadCategories();
      setState(() {
        _selectedCategory = categoryName;
        _isCreatingCategory = false;
      });
      _showMessage('Categoria "$categoryName" adicionada', Colors.green);
    } on ArgumentError catch (e) { // Captura erro de categoria duplicada
       setState(() => _isCreatingCategory = false);
      _showMessage(e.message, Colors.orange);
    } catch (e) {
      setState(() => _isCreatingCategory = false);
      _showMessage('Erro ao adicionar categoria', Colors.red);
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categories.isEmpty || _selectedCategory == 'Adicione as categorias aqui') {
      _showMessage('Por favor, selecione ou adicione uma categoria', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    // ✅ CORREÇÃO: Usar _selectedDateTime diretamente
    final finalDateTime = _selectedDateTime;

    // Garante que a data/hora não está no passado (com pequena margem)
    final now = DateTime.now();
    if (finalDateTime.isBefore(now.subtract(const Duration(seconds: 10)))) {
       // Opcional: Mostrar aviso ou ajustar para agora?
       // Por enquanto, vamos permitir salvar datas passadas, mas a notificação não será agendada.
       debugPrint("Aviso: Data/hora selecionada está no passado: $finalDateTime");
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
      // Mantém o estado de notificação original ao editar, a menos que seja alterado no dialog da lista
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
        if (reminder.notificationsEnabled && finalDateTime.isAfter(now.subtract(const Duration(seconds: 5)))) {
          // Apenas agenda se habilitado E data/hora não estiver muito no passado
          if (reminder.isRecurring) {
            await NotificationService.scheduleRecurringNotification(
              id: savedId,
              title: reminder.title,
              description: reminder.description,
              scheduledDate: reminder.getNextOccurrence(),
              category: reminder.category,
            );
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
        // Retorna o lembrete salvo/atualizado para a tela anterior
        Navigator.pop(context, reminder);
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

