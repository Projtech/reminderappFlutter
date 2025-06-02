import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/category_helper.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import 'dart:async'; // Para Timer
import 'package:flutter/foundation.dart'; // Para debugPrint

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminderToEdit;

  const AddReminderScreen({super.key, this.reminderToEdit});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newCategoryController = TextEditingController();

  late DateTime _selectedDateTime;
  late String _selectedCategory;
  late bool _isRecurring;
  bool _isEditing = false;
  bool _isLoadingCategories = true;
  bool _isCreatingCategory = false;
  bool _isSaving = false;

  List<Map<String, dynamic>> _categories = [];
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper();
  Color _selectedNewCategoryColor = Colors.grey;

  final List<Color> _predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.reminderToEdit != null;

    if (_isEditing) {
      final reminder = widget.reminderToEdit!;
      _titleController.text = reminder.title;
      _descriptionController.text = reminder.description ?? '';
      _selectedDateTime = reminder.dateTime;
      _selectedCategory = reminder.category;
      _isRecurring = reminder.isRecurring;
    } else {
      _selectedDateTime = DateTime.now();
      _selectedCategory =
          'Adicione as categorias aqui'; // Valor inicial antes de carregar
      _isRecurring = false;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      final loadedCategories = await _categoryHelper.getAllCategories();
      if (!mounted) return;
      setState(() {
        _categories = loadedCategories;
        if (_categories.isNotEmpty) {
          final categoryNames =
              _categories.map((c) => c['name'] as String).toList();
          // Se não estiver editando OU se a categoria do lembrete a editar não existir mais,
          // seleciona a primeira categoria da lista como padrão.
          if (!_isEditing || !categoryNames.contains(_selectedCategory)) {
            _selectedCategory = categoryNames.first;
          }
        } else {
          _selectedCategory = 'Adicione as categorias aqui';
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
      _showMessage('Erro ao carregar categorias', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Lembrete' : 'Novo Lembrete'),
        backgroundColor:
            isDark ? colorScheme.surfaceContainerHighest : colorScheme.primary,
        foregroundColor: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      backgroundColor:
          isDark ? colorScheme.surface : colorScheme.surfaceContainerLowest,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : theme.cardColor,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : theme.cardColor,
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colorScheme.primary),
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
                        Text('Carregando categorias...',
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant)),
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
    if (!categoryNames.contains(_selectedCategory) ||
        _selectedCategory == 'Adicione as categorias aqui') {
      _selectedCategory = categoryNames.first;
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      style: TextStyle(color: colorScheme.onSurface),
      dropdownColor: colorScheme.surfaceContainerHighest,
      decoration: const InputDecoration(border: InputBorder.none),
      items: _categories.map((category) {
        final name = category['name'] as String;
        final colorHex = category['color'] as String;
        Color color = Colors.grey;
        try {
          color = Color(int.parse(colorHex, radix: 16));
        } catch (e) {
          debugPrint(
              'Erro ao parsear cor $colorHex para categoria $name no dropdown: $e. Usando cor padrão.');
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : theme.cardColor,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : theme.cardColor,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : theme.cardColor,
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
      onPressed: _saveReminder,
      icon: const Icon(Icons.save),
      label: Text(_isEditing ? 'Atualizar Lembrete' : 'Salvar Lembrete'),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
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
    _newCategoryController.clear();
    _selectedNewCategoryColor = Colors.grey;

    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = _selectedNewCategoryColor;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Nova Categoria'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _newCategoryController,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Categoria',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Escolha uma cor:'),
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
                              border: _selectedNewCategoryColor == color
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 2)
                                  : null,
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
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final name = _newCategoryController.text.trim();
                    if (name.isNotEmpty && name.length <= 50) {
                      Navigator.pop(context);
                      await _addCategory(name, _selectedNewCategoryColor);
                    } else if (name.isEmpty) {
                      _showMessage('Nome da categoria não pode ser vazio',
                          Colors.orange);
                    } else {
                      _showMessage('Nome da categoria muito longo (máx. 50)',
                          Colors.orange);
                    }
                  },
                  child: const Text('Adicionar'),
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
      // Salva como AARRGGBB hex string
      final colorHex =
          color.value.toRadixString(16).padLeft(8, '0').toUpperCase();

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

    if (_selectedCategory == 'Adicione as categorias aqui' ||
        _categories.where((c) => c['name'] == _selectedCategory).isEmpty) {
      _showMessage('Por favor, selecione ou adicione uma categoria válida.',
          Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final finalDateTime = _selectedDateTime;

    // Adicionado para evitar agendar notificações no passado imediato
    if (finalDateTime.isBefore(now.subtract(const Duration(seconds: 1)))) {
      debugPrint(
          "Aviso: Data/hora selecionada ($finalDateTime) está no passado. Notificação não será agendada.");
    }

    final reminder = Reminder(
      id: _isEditing ? widget.reminderToEdit!.id : null,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      dateTime: finalDateTime,
      isCompleted: _isEditing ? widget.reminderToEdit!.isCompleted : false,
      isRecurring: _isRecurring,
      recurringType: _isRecurring
          ? 'monthly'
          : null, // Ajuste conforme sua lógica de recorrência
      notificationsEnabled:
          _isEditing ? widget.reminderToEdit!.notificationsEnabled : true,
    );

    try {
      int? savedId = reminder.id;
      if (_isEditing) {
        await _databaseHelper.updateReminder(reminder);
      } else {
        savedId = await _databaseHelper.insertReminder(reminder);
        reminder.id = savedId; // Atualiza o ID no objeto local
      }

      if (savedId != null) {
        await NotificationService.cancelNotification(savedId);
        // Apenas agenda se habilitado E data/hora não estiver muito no passado
        if (reminder.notificationsEnabled &&
            !reminder.isCompleted &&
            finalDateTime.isAfter(now.subtract(const Duration(seconds: 5)))) {
          if (reminder.isRecurring) {
            // A lógica de recorrência mensal precisa ser implementada corretamente.
            // O NotificationService atual pode não suportar RepeatInterval.monthly diretamente.
            // Agendaremos apenas a próxima ocorrência.
            DateTime nextOccurrence = reminder.getNextOccurrence();
            debugPrint(
                "Agendando notificação recorrente (próxima ocorrência) para: $nextOccurrence");
            await NotificationService.scheduleNotification(
              id: savedId,
              title: "(Recorrente) ${reminder.title}",
              description: reminder.description,
              scheduledDate: nextOccurrence,
              category: reminder.category,
            );
            // Nota: O app precisaria ter lógica para reagendar a notificação após ela disparar.
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
