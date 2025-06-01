import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// REMOVIDO: import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/reminder.dart';
import '../database/category_helper.dart';
import '../database/database_helper.dart'; // ADICIONADO: Import DatabaseHelper

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
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isRecurring = false;

  List<Map<String, dynamic>> _categories = [];
  final CategoryHelper _categoryHelper = CategoryHelper();
  final DatabaseHelper _databaseHelper = DatabaseHelper(); // ADICIONADO: Instância do DatabaseHelper

  bool _isLoadingCategories = true;
  bool _isSaving = false;
  bool _isCreatingCategory = false;

  bool get _isEditing => widget.reminderToEdit != null;

  @override
  void initState() {
    super.initState();
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
    _selectedDate = reminder.dateTime;
    _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);
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
          // Se estiver editando e a categoria existir, mantém. Senão, seleciona a primeira.
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
      backgroundColor: colorScheme.background,
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

    // Garante que _selectedCategory seja um valor válido na lista
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
        final color = Color(int.parse(colorHex));

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
                DateFormat('dd/MM/yyyy').format(_selectedDate),
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
                _selectedTime.format(context),
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

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveReminder,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(_isEditing ? Icons.update : Icons.save),
        label: Text(
          _isEditing ? 'Atualizar Lembrete' : 'Salvar Lembrete',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- Funções Auxiliares (Seleção de Data/Hora, Salvar, Categoria) ---

  Future<void> _selectDate() async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final theme = Theme.of(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
             timePickerTheme: TimePickerThemeData(
               backgroundColor: theme.dialogBackgroundColor,
               hourMinuteTextColor: theme.colorScheme.onSurface,
               hourMinuteColor: theme.colorScheme.surfaceVariant,
               dayPeriodTextColor: theme.colorScheme.onSurface,
               dayPeriodColor: theme.colorScheme.surfaceVariant,
               dialHandColor: theme.colorScheme.primary,
               dialBackgroundColor: theme.colorScheme.surfaceVariant,
               dialTextColor: theme.colorScheme.onSurface,
               entryModeIconColor: theme.colorScheme.primary,
               helpTextStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
             ),
             textButtonTheme: TextButtonThemeData(
               style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
             ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _showAddCategoryDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // REMOVIDO: Color selectedColor = colorScheme.primary;
    _newCategoryController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text('Nova Categoria', style: TextStyle(color: colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newCategoryController,
                  maxLength: 50,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Nome da categoria',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                ),
                // REMOVIDO: Seção de seleção de cor com BlockPicker
                // const SizedBox(height: 20),
                // const Text('Escolha uma cor:', style: TextStyle(fontSize: 16)),
                // const SizedBox(height: 10),
                // BlockPicker(...),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancelar', style: TextStyle(color: colorScheme.primary)),
            ),
            TextButton(
              onPressed: () async {
                final categoryName = _newCategoryController.text.trim();
                if (categoryName.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  // CORREÇÃO: Usar uma cor padrão (ex: Colors.grey) ou gerar uma aleatória simples
                  final defaultColor = Colors.grey; // Ou outra cor padrão
                  await _createCategory(categoryName, defaultColor);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Digite um nome para a categoria.'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('Adicionar', style: TextStyle(color: colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createCategory(String name, Color color) async {
    if (!mounted) return;
    setState(() => _isCreatingCategory = true);
    try {
      // Usa toRadixString(16) para obter o valor hexadecimal da cor
      final colorHex = color.value.toRadixString(16);
      await _categoryHelper.insertCategory(name, colorHex);
      await _loadCategories();
      if (mounted) {
         setState(() {
           _selectedCategory = name;
           _isCreatingCategory = false;
         });
        _showMessage('Categoria "$name" criada!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingCategory = false);
        _showMessage('Erro ao criar categoria: $e', Colors.red);
      }
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Por favor, corrija os erros no formulário.', Colors.orange);
      return;
    }

    if (_selectedCategory == 'Adicione as categorias aqui' || _categories.indexWhere((c) => c['name'] == _selectedCategory) == -1) {
       _showMessage('Por favor, selecione ou crie uma categoria válida.', Colors.orange);
       return;
    }

    setState(() => _isSaving = true);

    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminder = Reminder(
      id: _isEditing ? widget.reminderToEdit!.id : null,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      dateTime: combinedDateTime,
      isCompleted: _isEditing ? widget.reminderToEdit!.isCompleted : false,
      isRecurring: _isRecurring,
      recurringType: _isRecurring ? 'monthly' : null,
      notificationsEnabled: _isEditing ? widget.reminderToEdit!.notificationsEnabled : true,
    );

    try {
      // CORREÇÃO: Usar a instância _databaseHelper diretamente
      if (_isEditing) {
        await _databaseHelper.updateReminder(reminder);
        _showMessage('Lembrete atualizado com sucesso!', Colors.green);
      } else {
        await _databaseHelper.insertReminder(reminder);
        _showMessage('Lembrete salvo com sucesso!', Colors.green);
      }
      if (mounted) {
        Navigator.pop(context, reminder);
      }
    } catch (e) {
      _showMessage('Erro ao salvar lembrete: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
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

