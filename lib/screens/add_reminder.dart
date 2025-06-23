import '../services/pix_suggestion_service.dart';
import '../widgets/pix_suggestion_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../database/category_helper.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import '../models/checklist_item.dart';
import '../services/notification_service.dart';
import 'dart:async';

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
  final _customIntervalController = TextEditingController();
  final _newItemController = TextEditingController();

  late DateTime _selectedDateTime;
  late String _selectedCategory;
  late String _selectedRecurrenceType;
  late int _customInterval;
  late String _customUnit;

  bool _isEditing = false;
  bool _isLoadingCategories = true;
  bool _isCreatingCategory = false;
  bool _isSaving = false;
  bool _isChecklist = false;
  bool _isAddingItem = false;

  Map<String, Map<String, dynamic>> _categoriesMap = {};
  List<String> _normalizedCategoryNames = [];
  List<ChecklistItem> _checklistItems = [];

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

  final List<Map<String, String>> _recurrenceOptions = [
    {'value': 'none', 'label': 'Não repetir'},
    {'value': 'daily', 'label': 'Diariamente'},
    {'value': 'weekly', 'label': 'Semanalmente'},
    {'value': 'monthly', 'label': 'Mensalmente'},
    {'value': 'custom', 'label': 'Personalizado'},
  ];

  final List<Map<String, String>> _customUnits = [
    {'value': 'days', 'label': 'dias'},
    {'value': 'weeks', 'label': 'semanas'},
    {'value': 'months', 'label': 'meses'},
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.reminderToEdit != null;

    if (_isEditing) {
      final reminder = widget.reminderToEdit!;
      _titleController.text = reminder.title;
      _descriptionController.text = reminder.description;
      _selectedDateTime = reminder.dateTime;
      _selectedCategory = reminder.category.toLowerCase();

      _selectedRecurrenceType = reminder.recurringType ?? 'none';
      _customInterval = reminder.recurrenceInterval;
      _customIntervalController.text = _customInterval.toString();

      _isChecklist = reminder.isChecklist;
      _checklistItems = List.from(reminder.checklistItems ?? []);

      if (_selectedRecurrenceType.startsWith('custom_')) {
        if (_selectedRecurrenceType == 'custom_daily') {
          _customUnit = 'days';
        } else if (_selectedRecurrenceType == 'custom_weekly') {
          _customUnit = 'weeks';
        } else if (_selectedRecurrenceType == 'custom_monthly') {
          _customUnit = 'months';
        } else {
          _customUnit = 'days';
        }
        _selectedRecurrenceType = 'custom';
      } else {
        _customUnit = 'days';
      }
    } else {
      _selectedDateTime = DateTime.now();
      _selectedCategory = '';
      _selectedRecurrenceType = 'none';
      _customInterval = 1;
      _customUnit = 'days';
      _customIntervalController.text = '1';
    }

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryHelper.getAllCategories();
      final Map<String, Map<String, dynamic>> tempCategoriesMap = {};
      final List<String> tempNormalizedNames = [];

      for (final catMap in categories) {
        final originalName = catMap['name'] as String? ?? '';
        final normalizedName = originalName.trim().toLowerCase();
        if (normalizedName.isEmpty) continue;

        final colorHex = catMap['color'] as String? ?? 'FF808080';
        final color = _parseColorHex(colorHex, normalizedName);

        tempCategoriesMap[normalizedName] = {
          'originalName': originalName,
          'colorHex': colorHex,
          'color': color,
        };
        tempNormalizedNames.add(normalizedName);
      }

      tempNormalizedNames.sort();

      setState(() {
        _categoriesMap = tempCategoriesMap;
        _normalizedCategoryNames = tempNormalizedNames;

        if (_normalizedCategoryNames.isNotEmpty) {
          if (!_normalizedCategoryNames.contains(_selectedCategory) ||
              _selectedCategory.isEmpty) {
            _selectedCategory = _normalizedCategoryNames.first;
          }
        } else {
          _selectedCategory = '';
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
      _showMessage('Erro ao carregar categorias', Colors.red);
    }
  }

  Color _parseColorHex(String colorHex, String normalizedName) {
    try {
      if (colorHex.length == 6) {
        return Color(int.parse('FF$colorHex', radix: 16));
      } else if (colorHex.length == 8) {
        return Color(int.parse(colorHex, radix: 16));
      }
    } catch (e) {
      // Ignore error and use default
    }

    switch (normalizedName) {
      case 'trabalho':
        return Colors.blue;
      case 'pessoal':
        return Colors.green;
      case 'saúde':
        return Colors.red;
      case 'estudo':
        return Colors.orange;
      case 'casa':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _addChecklistItem() {
    final text = _newItemController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _checklistItems.add(ChecklistItem(
          text: text,
          order: _checklistItems.length,
        ));
        _newItemController.clear();
        _isAddingItem = false;
      });
    }
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _checklistItems.removeAt(index);
      // Reordenar os items
      for (int i = 0; i < _checklistItems.length; i++) {
        _checklistItems[i] = _checklistItems[i].copyWith(order: i);
      }
    });
  }

  void _toggleChecklistItem(int index) {
    setState(() {
      _checklistItems[index] = _checklistItems[index].copyWith(
        isCompleted: !_checklistItems[index].isCompleted,
      );
    });
  }

  void _reorderChecklistItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _checklistItems.removeAt(oldIndex);
      _checklistItems.insert(newIndex, item);

      // Reordenar os items
      for (int i = 0; i < _checklistItems.length; i++) {
        _checklistItems[i] = _checklistItems[i].copyWith(order: i);
      }
    });
  }

  Future<void> _selectDate() async {
    DateTime tempDate = _selectedDateTime;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                  const Text(
                    'Selecionar Data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDateTime = DateTime(
                          tempDate.year,
                          tempDate.month,
                          tempDate.day,
                          _selectedDateTime.hour,
                          _selectedDateTime.minute,
                        );
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDateTime,
                minimumDate: DateTime.now().subtract(const Duration(days: 365)),
                maximumDate: DateTime.now().add(const Duration(days: 365 * 5)),
                onDateTimeChanged: (DateTime newDate) {
                  tempDate = newDate;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    DateTime tempTime = _selectedDateTime;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                  const Text(
                    'Selecionar Hora',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDateTime = DateTime(
                          _selectedDateTime.year,
                          _selectedDateTime.month,
                          _selectedDateTime.day,
                          tempTime.hour,
                          tempTime.minute,
                        );
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _selectedDateTime,
                use24hFormat: true,
                onDateTimeChanged: (DateTime newTime) {
                  tempTime = newTime;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  // lib/screens/add_reminder.dart - PARTE 2

  Future<void> _addNewCategory() async {
    final categoryName = _newCategoryController.text.trim();
    if (categoryName.isEmpty) {
      _showMessage('Digite o nome da categoria', Colors.orange);
      return;
    }

    final normalizedName = categoryName.toLowerCase();
    if (_normalizedCategoryNames.contains(normalizedName)) {
      _showMessage('Esta categoria já existe!', Colors.orange);
      return;
    }

    setState(() => _isCreatingCategory = true);

    try {
      final colorHex = _selectedNewCategoryColor
          .toARGB32()
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2);

      await _categoryHelper.addCategory(categoryName, colorHex);
      await _loadCategories();
      setState(() {
        _selectedCategory = normalizedName;
        _newCategoryController.clear();
        _selectedNewCategoryColor = Colors.grey;
        _isCreatingCategory = false;
      });

      if (mounted) {
        Navigator.pop(context);
        _showMessage('Categoria adicionada com sucesso!', Colors.green);
      }
    } catch (e) {
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

    if (_selectedCategory.isEmpty ||
        !_normalizedCategoryNames.contains(_selectedCategory)) {
      _showMessage('Por favor, selecione ou adicione uma categoria válida.',
          Colors.orange);
      return;
    }

    if (_isChecklist && _checklistItems.isEmpty) {
      _showMessage('Adicione pelo menos um item ao checklist.', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      String finalRecurringType = 'none';
      int finalInterval = 1;
      bool isRecurring = false;

      if (_selectedRecurrenceType != 'none') {
        isRecurring = true;

        if (_selectedRecurrenceType == 'custom') {
          switch (_customUnit) {
            case 'days':
              finalRecurringType = 'custom_daily';
              break;
            case 'weeks':
              finalRecurringType = 'custom_weekly';
              break;
            case 'months':
              finalRecurringType = 'custom_monthly';
              break;
          }
          finalInterval = _customInterval;
        } else {
          finalRecurringType = _selectedRecurrenceType;
          finalInterval = 1;
        }
      }

      final reminder = Reminder(
        id: _isEditing ? widget.reminderToEdit!.id : null,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        dateTime: _selectedDateTime,
        createdAt:
            _isEditing ? widget.reminderToEdit!.createdAt : DateTime.now(),
        isCompleted: _isEditing ? widget.reminderToEdit!.isCompleted : false,
        isRecurring: isRecurring,
        recurringType: isRecurring ? finalRecurringType : null,
        recurrenceInterval: finalInterval,
        notificationsEnabled:
            _isEditing ? widget.reminderToEdit!.notificationsEnabled : true,
        isChecklist: _isChecklist,
        checklistItems: _isChecklist ? _checklistItems : null,
      );

      int? savedId = reminder.id;
      if (_isEditing) {
        await _databaseHelper.updateReminder(reminder);
      } else {
        savedId = await _databaseHelper.insertReminder(reminder);
        reminder.id = savedId;
      }

      if (savedId != null) {
        await NotificationService.cancelNotification(savedId);

        if (reminder.notificationsEnabled && !reminder.isCompleted) {
          await NotificationService.scheduleReminderNotifications(reminder);
        }
      }

// pix

      if (mounted) {
        // 1. PRIMEIRO: Fazer o pop e voltar para a tela de lembretes
        Navigator.pop(context, true);

        // 2. DEPOIS: Trigger do PIX (sem await para não bloquear)
        _triggerPixSuggestion();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showMessage('Erro ao salvar lembrete', Colors.red);
      }
    }
  }

  Future<void> _triggerPixSuggestion() async {
    if (_isEditing) return;

    try {
      // Delay menor para não bloquear o pop
      await Future.delayed(const Duration(milliseconds: 200));

      final pixService = PixSuggestionService();
      await pixService.init();
      await pixService.registerPositiveAction();

      final shouldSuggest = await pixService.shouldSuggestPix();

      if (shouldSuggest && mounted) {
        await pixService.registerSuggestionShown();

        showDialog(
          context: context,
          builder: (context) => PixSuggestionDialog(
            onSupported: () {
              pixService.registerUserSupported();
            },
            onDeclined: () {
              pixService.registerUserDeclined();
            },
          ),
        );
      }
    } catch (e) {
      // Falha silenciosa
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
          _buildTypeToggleCard(),
          const SizedBox(height: 16),
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
          if (!_isChecklist) ...[
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
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isChecklist) ...[
            _buildChecklistCard(),
            const SizedBox(height: 16),
          ],
          _buildCategoryCard(),
          const SizedBox(height: 16),
          if (!_isChecklist) ...[
            _buildRecurrenceCard(),
            const SizedBox(height: 16),
          ],
          _buildDateCard(),
          const SizedBox(height: 16),
          _buildTimeCard(),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildTypeToggleCard() {
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
            color: theme.shadowColor.withValues(alpha: 0.1),
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
                'Tipo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isChecklist = false;
                      _checklistItems.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: !_isChecklist
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_isChecklist
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications,
                          color: !_isChecklist
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lembrete',
                          style: TextStyle(
                            color: !_isChecklist
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isChecklist = true;
                      if (_checklistItems.isEmpty) {
                        _checklistItems.add(ChecklistItem(text: '', order: 0));
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isChecklist
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isChecklist
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist,
                          color: _isChecklist
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Checklist',
                          style: TextStyle(
                            color: _isChecklist
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
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
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Items do Checklist',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (_checklistItems.isNotEmpty)
                Text(
                  '${_checklistItems.where((item) => item.isCompleted).length}/${_checklistItems.length}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_checklistItems.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_add,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum item adicionado',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toque no botão abaixo para adicionar items',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checklistItems.length,
              onReorder: _reorderChecklistItems,
              itemBuilder: (context, index) {
                final item = _checklistItems[index];
                return Container(
                  key: ValueKey(item.hashCode),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: GestureDetector(
                      onTap: () => _toggleChecklistItem(index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.isCompleted
                                ? Colors.green
                                : colorScheme.outline,
                            width: 2,
                          ),
                          color: item.isCompleted
                              ? Colors.green
                              : Colors.transparent,
                        ),
                        child: item.isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                    title: TextFormField(
                      initialValue: item.text,
                      style: TextStyle(
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Digite o item...',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        _checklistItems[index] = item.copyWith(text: value);
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drag_handle,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeChecklistItem(index),
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          if (_isAddingItem) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _newItemController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Digite o novo item...',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onFieldSubmitted: (_) => _addChecklistItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addChecklistItem,
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAddingItem = false;
                        _newItemController.clear();
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isAddingItem = true;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Item'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurrenceCard() {
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
            color: theme.shadowColor.withValues(alpha: 0.1),
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
              Icon(Icons.repeat, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Repetição',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRecurrenceType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _recurrenceOptions.map((option) {
              return DropdownMenuItem(
                value: option['value'],
                child: Text(option['label']!),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRecurrenceType = value!;
              });
            },
          ),
          if (_selectedRecurrenceType == 'custom') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customIntervalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'A cada',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Digite um número';
                      }
                      final number = int.tryParse(value.trim());
                      if (number == null || number < 1) {
                        return 'Número inválido';
                      }
                      if (_customUnit == 'days' && number > 365) {
                        return 'Máximo 365 dias';
                      }
                      if (_customUnit == 'weeks' && number > 52) {
                        return 'Máximo 52 semanas';
                      }
                      if (_customUnit == 'months' && number > 12) {
                        return 'Máximo 12 meses';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final number = int.tryParse(value.trim()) ?? 1;
                      setState(() {
                        _customInterval = number;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _customUnit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _customUnits.map((unit) {
                      return DropdownMenuItem(
                        value: unit['value'],
                        child: Text(unit['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _customUnit = value!;
                        if (value == 'months' && _customInterval > 12) {
                          _customInterval = 12;
                          _customIntervalController.text = '12';
                        } else if (value == 'weeks' && _customInterval > 52) {
                          _customInterval = 52;
                          _customIntervalController.text = '52';
                        } else if (value == 'days' && _customInterval > 365) {
                          _customInterval = 365;
                          _customIntervalController.text = '365';
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getCustomRecurrencePreview(),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getCustomRecurrencePreview() {
    if (_selectedRecurrenceType != 'custom') return '';

    final interval = _customInterval;
    final unit = _customUnit;

    if (interval == 1) {
      switch (unit) {
        case 'days':
          return 'Repetir todos os dias';
        case 'weeks':
          return 'Repetir toda semana';
        case 'months':
          return 'Repetir todo mês';
      }
    }

    switch (unit) {
      case 'days':
        return 'Repetir a cada $interval dias';
      case 'weeks':
        return 'Repetir a cada $interval semanas';
      case 'months':
        return 'Repetir a cada $interval meses';
      default:
        return '';
    }
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
            color: theme.shadowColor.withValues(alpha: 0.1),
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
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAddCategoryDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nova'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingCategories)
            const Center(child: CircularProgressIndicator())
          else
            _buildCategoryDropdown(),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _normalizedCategoryNames.contains(_selectedCategory)
          ? _selectedCategory
          : null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      hint: const Text('Selecione uma categoria'),
      items: _normalizedCategoryNames.map((normalizedName) {
        final categoryData = _categoriesMap[normalizedName]!;
        final originalName = categoryData['originalName'] as String;
        final color = categoryData['color'] as Color? ?? Colors.grey;

        return DropdownMenuItem(
          value: normalizedName,
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
              Text(originalName),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCategory = value);
        }
      },
      validator: (value) {
        if (value == null ||
            value.isEmpty ||
            !_normalizedCategoryNames.contains(value)) {
          return 'Selecione uma categoria válida';
        }
        return null;
      },
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
            color: theme.shadowColor.withValues(alpha: 0.1),
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
            color: theme.shadowColor.withValues(alpha: 0.1),
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
            'Hora',
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
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saveReminder,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _isEditing
              ? (_isChecklist ? 'Atualizar Checklist' : 'Atualizar Lembrete')
              : (_isChecklist ? 'Salvar Checklist' : 'Salvar Lembrete'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    Color tempSelectedColor = _selectedNewCategoryColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Categoria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _newCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Nome da categoria',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 16),
              const Text('Escolha uma cor:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _predefinedColors.map((color) {
                  final isSelected = tempSelectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        tempSelectedColor = color;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _isCreatingCategory
                  ? null
                  : () {
                      setState(() {
                        _selectedNewCategoryColor = tempSelectedColor;
                      });
                      _addNewCategory();
                    },
              child: _isCreatingCategory
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    _customIntervalController.dispose();
    _newItemController.dispose();
    super.dispose();
  }
}
