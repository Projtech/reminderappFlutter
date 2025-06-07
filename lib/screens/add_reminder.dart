import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/category_helper.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
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
  final _customIntervalController = TextEditingController(); // ✅ NOVO

  late DateTime _selectedDateTime;
  late String _selectedCategory;
  late String _selectedRecurrenceType; // ✅ NOVO: none, daily, weekly, monthly, custom_daily, custom_weekly, custom_monthly
  late int _customInterval; // ✅ NOVO: para repetições personalizadas
  late String _customUnit; // ✅ NOVO: days, weeks, months
  
  bool _isEditing = false;
  bool _isLoadingCategories = true;
  bool _isCreatingCategory = false;
  bool _isSaving = false;

  Map<String, Map<String, dynamic>> _categoriesMap = {};
  List<String> _normalizedCategoryNames = [];

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper();
  Color _selectedNewCategoryColor = Colors.grey;

  final List<Color> _predefinedColors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
    Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
    Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
    Colors.brown, Colors.grey, Colors.blueGrey
  ];

  // ✅ OPÇÕES DE REPETIÇÃO
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
      _selectedCategory = reminder.category.trim().toLowerCase();
      
      // ✅ CONFIGURAR REPETIÇÃO BASEADA NO LEMBRETE EXISTENTE
      if (reminder.isRecurring && reminder.recurringType != null) {
        _selectedRecurrenceType = reminder.recurringType!;
        _customInterval = reminder.recurrenceInterval;
        
        // Determinar unidade para tipos customizados
        if (reminder.recurringType!.startsWith('custom_')) {
          if (reminder.recurringType == 'custom_daily') {
            _customUnit = 'days';
          } else if (reminder.recurringType == 'custom_weekly') {
            _customUnit = 'weeks';
          } else if (reminder.recurringType == 'custom_monthly') {
            _customUnit = 'months';
          }
          _selectedRecurrenceType = 'custom'; // Para a interface
        } else {
          _customUnit = 'days';
        }
      } else {
        _selectedRecurrenceType = 'none';
        _customInterval = 1;
        _customUnit = 'days';
      }
    } else {
      _selectedDateTime = DateTime.now();
      _selectedCategory = '';
      _selectedRecurrenceType = 'none';
      _customInterval = 1;
      _customUnit = 'days';
    }
    
    _customIntervalController.text = _customInterval.toString();
    _loadCategories();
  }

  Color _parseColorHex(String hex, String categoryName) {
    String hexUpper = hex.toUpperCase().replaceAll('#', '');
    if (hexUpper.length == 6) {
      hexUpper = 'FF$hexUpper';
    }
    if (hexUpper.length != 8) {
      return Colors.grey;
    }
    try {
      return Color(int.parse(hexUpper, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      final loadedCategoriesData = await _categoryHelper.getAllCategories();
      if (!mounted) return;

      final tempCategoriesMap = <String, Map<String, dynamic>>{};
      final tempNormalizedNames = <String>[];

      for (final catMap in loadedCategoriesData) {
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
          if (!_normalizedCategoryNames.contains(_selectedCategory) || _selectedCategory.isEmpty) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Lembrete' : 'Novo Lembrete'),
        backgroundColor: isDark ? colorScheme.surfaceContainerHighest : colorScheme.primary,
        foregroundColor: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      backgroundColor: isDark ? colorScheme.surface : colorScheme.surfaceContainerLowest,
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
          _buildRecurrenceCard(), // ✅ NOVO CARD DE REPETIÇÃO
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

  // ✅ NOVO CARD DE REPETIÇÃO COMPLETO
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
            // ignore: deprecated_member_use
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
          
          // Dropdown de tipo de repetição
          DropdownButtonFormField<String>(
            value: _selectedRecurrenceType,
            style: TextStyle(color: colorScheme.onSurface),
            dropdownColor: colorScheme.surfaceContainerHighest,
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
                if (value != 'custom') {
                  _customInterval = 1;
                  _customIntervalController.text = '1';
                }
              });
            },
          ),
          
          // Seção personalizada (aparece só quando "Personalizado" está selecionado)
          if (_selectedRecurrenceType == 'custom') ...[
            const SizedBox(height: 16),
            Text(
              'Configuração Personalizada',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'A cada',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _customIntervalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    validator: (value) {
                      if (_selectedRecurrenceType == 'custom') {
                        final interval = int.tryParse(value ?? '');
                        if (interval == null || interval < 1) {
                          return 'Min: 1';
                        }
                        // Limites máximos baseados na unidade
                        if (_customUnit == 'days' && interval > 365) {
                          return 'Max: 365';
                        } else if (_customUnit == 'weeks' && interval > 52) {
                          return 'Max: 52';
                        } else if (_customUnit == 'months' && interval > 12) {
                          return 'Max: 12';
                        }
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final interval = int.tryParse(value);
                      if (interval != null && interval > 0) {
                        _customInterval = interval;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _customUnit,
                    style: TextStyle(color: colorScheme.onSurface),
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        // Resetar intervalo para valores seguros
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
        case 'days': return 'Repetir todos os dias';
        case 'weeks': return 'Repetir toda semana';
        case 'months': return 'Repetir todo mês';
      }
    }
    
    switch (unit) {
      case 'days': return 'Repetir a cada $interval dias';
      case 'weeks': return 'Repetir a cada $interval semanas';
      case 'months': return 'Repetir a cada $interval meses';
      default: return '';
    }
  }

  // [Restante dos widgets buildSimpleCard, buildCategoryCard, etc. permanecem iguais...]
  
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
            // ignore: deprecated_member_use
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
            // ignore: deprecated_member_use
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
                            style: TextStyle(color: colorScheme.onSurfaceVariant)),
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

    if (_normalizedCategoryNames.isEmpty) {
      return Text(
        'Nenhuma categoria encontrada. Adicione uma clicando no +.',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }

    if (!_normalizedCategoryNames.contains(_selectedCategory)) {
       _selectedCategory = _normalizedCategoryNames.first;
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      style: TextStyle(color: colorScheme.onSurface),
      dropdownColor: colorScheme.surfaceContainerHighest,
      decoration: const InputDecoration(border: InputBorder.none),
      items: _normalizedCategoryNames.map((normalizedName) {
        final categoryData = _categoriesMap[normalizedName];
        final color = categoryData?['color'] as Color? ?? Colors.grey;

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
              Text(normalizedName),
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
         if (value == null || value.isEmpty || !_normalizedCategoryNames.contains(value)) {
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
            // ignore: deprecated_member_use
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
            // ignore: deprecated_member_use
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
                                      color: Theme.of(context).colorScheme.onSurface,
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
                    final normalizedName = _newCategoryController.text.trim().toLowerCase();
                    if (normalizedName.isNotEmpty && normalizedName.length <= 50) {
                      if (_normalizedCategoryNames.contains(normalizedName)) {
                         _showMessage('Categoria "$normalizedName" já existe.', Colors.orange);
                      } else {
                        Navigator.pop(context);
                        await _addCategory(normalizedName, _selectedNewCategoryColor);
                      }
                    } else if (normalizedName.isEmpty) {
                      _showMessage('Nome da categoria não pode ser vazio', Colors.orange);
                    } else {
                      _showMessage('Nome da categoria muito longo (máx. 50)', Colors.orange);
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

  Future<void> _addCategory(String normalizedName, Color color) async {
    if (!mounted) return;
    setState(() => _isCreatingCategory = true);
    try {
      // ignore: deprecated_member_use
      final colorHex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
      await _categoryHelper.addCategory(normalizedName, colorHex);
      await _loadCategories();
      if (mounted) {
        setState(() {
          _selectedCategory = normalizedName;
          _isCreatingCategory = false;
        });
        _showMessage('Categoria "$normalizedName" adicionada!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingCategory = false);
        _showMessage('Erro ao adicionar categoria', Colors.red);
      }
    }
  }

  // ✅ LÓGICA DE SALVAMENTO ATUALIZADA
  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Por favor, corrija os erros no formulário.', Colors.orange);
      return;
    }

    if (_selectedCategory.isEmpty || !_normalizedCategoryNames.contains(_selectedCategory)) {
      _showMessage('Por favor, selecione ou adicione uma categoria válida.', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      // ✅ DETERMINAR TIPO DE REPETIÇÃO E INTERVALO
      String finalRecurringType = 'none';
      int finalInterval = 1;
      bool isRecurring = false;

      if (_selectedRecurrenceType != 'none') {
        isRecurring = true;
        
        if (_selectedRecurrenceType == 'custom') {
          // Repetição personalizada
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
          // Repetição padrão
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
        isCompleted: _isEditing ? widget.reminderToEdit!.isCompleted : false,
        isRecurring: isRecurring,
        recurringType: isRecurring ? finalRecurringType : null,
        recurrenceInterval: finalInterval,
        notificationsEnabled: _isEditing ? widget.reminderToEdit!.notificationsEnabled : true,
      );

      int? savedId = reminder.id;
      if (_isEditing) {
        await _databaseHelper.updateReminder(reminder);
      } else {
        savedId = await _databaseHelper.insertReminder(reminder);
        reminder.id = savedId;
      }

      // ✅ AGENDAR NOTIFICAÇÕES (MÚLTIPLAS SE RECORRENTE)
      if (savedId != null) {
        await NotificationService.cancelNotification(savedId);
        
        if (reminder.notificationsEnabled && !reminder.isCompleted) {
          await NotificationService.scheduleReminderNotifications(reminder);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
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
    _customIntervalController.dispose(); // ✅ NOVO
    super.dispose();
  }
}