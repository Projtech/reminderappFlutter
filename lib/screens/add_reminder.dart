import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../database/category_helper.dart';


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
          if (!categoryNames.contains(_selectedCategory)) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar Lembrete' : 'Novo Lembrete',
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isSaving ? _buildLoadingOverlay() : _buildMainContent(),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5), // ✅ CORRIGIDO
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(50),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 20),
              Text(
                _isEditing ? 'Atualizando lembrete...' : 'Salvando lembrete...',
                style: const TextStyle(fontSize: 16),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // ✅ CORRIGIDO
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // ✅ CORRIGIDO
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
              Icon(icon, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // ✅ CORRIGIDO
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // ✅ CORRIGIDO
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
              const Icon(Icons.category, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Categoria',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_isCreatingCategory)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _showAddCategoryDialog,
                  icon: const Icon(Icons.add, color: Colors.teal),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingCategories 
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Colors.teal),
                      SizedBox(height: 8),
                      Text('Carregando categorias...'),
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
    if (_categories.isEmpty) {
      return const Text(
        'Nenhuma categoria encontrada',
        style: TextStyle(color: Colors.grey),
      );
    }

    final categoryNames = _categories.map((c) => c['name'] as String).toList();
    if (!categoryNames.contains(_selectedCategory)) {
      _selectedCategory = categoryNames.first;
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // ✅ CORRIGIDO
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // ✅ CORRIGIDO
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.repeat, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Repetir Mensalmente',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Switch(
            value: _isRecurring,
            onChanged: (value) => setState(() => _isRecurring = value),
            activeColor: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // ✅ CORRIGIDO
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // ✅ CORRIGIDO
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Data',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                color: Colors.teal.withOpacity(0.1), // ✅ CORRIGIDO
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: const TextStyle(
                  color: Colors.teal,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // ✅ CORRIGIDO
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // ✅ CORRIGIDO
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Horário',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                color: Colors.teal.withOpacity(0.1), // ✅ CORRIGIDO
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedTime.format(context),
                style: const TextStyle(
                  color: Colors.teal,
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
    child: ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveReminder,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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

  void _showAddCategoryDialog() {
    Color selectedColor = Colors.blue;
    _newCategoryController.clear();
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCategoryController,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Escolha uma cor:'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Colors.blue, Colors.green, Colors.red, Colors.orange,
                  Colors.purple, Colors.pink, Colors.cyan, Colors.amber,
                ].map((color) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => selectedColor = color);
                      Navigator.of(dialogContext).pop();
                      _createCategory(selectedColor);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newCategoryController.clear();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCategory(Color selectedColor) async {
    final name = _newCategoryController.text.trim();
    
    if (name.isEmpty) {
      _showMessage('Digite o nome da categoria', Colors.red);
      return;
    }

    setState(() => _isCreatingCategory = true);

    try {
      final result = await _categoryHelper.insertCategory(
        name,
        '0x${selectedColor.toARGB32().toRadixString(16).toUpperCase()}',
      );
      
      if (!mounted) return;
      
      setState(() => _isCreatingCategory = false);
      
      if (result != -1) {
        await _loadCategories();
        setState(() => _selectedCategory = name);
        _newCategoryController.clear();
        _showMessage('Categoria "$name" criada!', Colors.green);
      } else {
        _showMessage('Categoria já existe!', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingCategory = false);
        _showMessage('Erro ao criar categoria', Colors.red);
      }
    }
  }

  Future<void> _selectDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime.now(),
        lastDate: DateTime(2030, 12, 31),
      );
      
      if (picked != null && picked != _selectedDate) {
        setState(() => _selectedDate = picked);
      }
    } catch (e) {
      _showMessage('Erro ao selecionar data', Colors.red);
    }
  }

  Future<void> _selectTime() async {
    try {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );
      
      if (picked != null && picked != _selectedTime) {
        setState(() => _selectedTime = picked);
      }
    } catch (e) {
      _showMessage('Erro ao selecionar horário', Colors.red);
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final DateTime reminderDateTime = DateTime(
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
        dateTime: reminderDateTime,
        isRecurring: _isRecurring,
        recurringType: _isRecurring ? 'monthly' : null,
        notificationsEnabled: _isEditing 
          ? widget.reminderToEdit!.notificationsEnabled 
          : true,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pop(context, reminder);
      
    } catch (e) {
      if (mounted) {
        _showMessage('Erro ao salvar lembrete', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
        margin: const EdgeInsets.all(16),
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