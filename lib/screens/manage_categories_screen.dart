import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Importar color picker
import '../database/category_helper.dart';
import '../database/database_helper.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  final CategoryHelper _categoryHelper = CategoryHelper();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // ✅ Para o dialog de adicionar categoria
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Color _selectedColor = Colors.blue; // Cor inicial padrão

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryHelper.getAllCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Erro ao carregar categorias', Colors.red);
    }
  }

  Future<void> _deleteCategory(int categoryId, String categoryName) async {
    if (_categories.length <= 1) {
        if (mounted) {
          _showMessage(
            'Não é possível excluir a última categoria.', Colors.orange);
        }
      return;
    }

    try {
      final reminderCount = await _databaseHelper.getReminderCountByCategory(categoryName);
      if (reminderCount > 0) {
        // BUG FIX: Add mounted check before showing SnackBar across async gap
        if (mounted) {
          _showMessage(
            'Não é possível excluir: existem $reminderCount lembrete(s) nesta categoria.', Colors.orange);
        }
        return;
      }
    } catch (e) {
      // BUG FIX: Add mounted check before showing SnackBar across async gap
      if (mounted) {
        _showMessage(
          'Erro ao verificar lembretes associados.', Colors.red);
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a categoria "$categoryName"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _categoryHelper.deleteCategory(categoryId);
        _showMessage('Categoria "$categoryName" excluída com sucesso.', Colors.green);
        _loadCategories();
      } catch (e) {
        _showMessage('Erro ao excluir categoria.', Colors.red);
      }
    }
  }

  // ✅ Função para mostrar o dialog de adicionar categoria
  Future<void> _showAddCategoryDialog() async {
    _nameController.clear();
    _selectedColor = Colors.blue; // Reseta a cor padrão

    await showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder( // Necessário para atualizar a cor selecionada no dialog
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Nova Categoria'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Categoria',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira um nome.';
                          }
                          // Verifica se a categoria já existe (case-insensitive)
                          if (_categories.any((cat) => cat['name'].toString().toLowerCase() == value.trim().toLowerCase())) {
                             return 'Esta categoria já existe.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Selecione uma cor:', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      // Usando BlockPicker do flutter_colorpicker
                      BlockPicker(
                        pickerColor: _selectedColor,
                        onColorChanged: (color) {
                          setDialogState(() { // Atualiza a cor no estado do dialog
                            _selectedColor = color;
                          });
                        },
                        availableColors: const [
                          Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
                          Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
                          Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
                          Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
                          Colors.brown, Colors.grey, Colors.blueGrey
                        ],
                        layoutBuilder: (context, colors, child) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: colors.map((color) => child(color)).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await _addCategory();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ Função para adicionar a categoria
  Future<void> _addCategory() async {
    final name = _nameController.text.trim();
    // Converte a cor para formato hexadecimal #AARRGGBB e remove o alfa (usa apenas RRGGBB)
    final colorHex = _selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2);

    try {
      await _categoryHelper.addCategory(name, colorHex);
      _showMessage('Categoria "$name" adicionada com sucesso!', Colors.green);
      _loadCategories(); // Recarrega a lista após adicionar
    } catch (e) {
      _showMessage('Erro ao adicionar categoria.', Colors.red);
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Gerenciar Categorias', style: TextStyle(color: colorScheme.onPrimary)),
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma categoria encontrada. Toque no + para adicionar.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Espaço para o FAB não cobrir o último item
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final categoryId = category['id'] as int;
                    final categoryName = category['name'] as String;
                    final colorHex = category['color'] as String;
                    Color color = Colors.grey;
                    try {
                      // Adiciona 'FF' para opacidade total ao parsear RRGGBB
                      color = Color(int.parse('FF$colorHex', radix: 16));
                    } catch (e) {
                    }

                    bool canDelete = categoryName != 'Geral';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: theme.cardColor,
                      elevation: 1,
                      child: ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.dividerColor.withAlpha((0.5 * 255).round()), width: 1), // Corrigido de withOpacity
                          ),
                        ),
                        title: Text(categoryName, style: TextStyle(color: colorScheme.onSurface)),
                        trailing: canDelete
                            ? IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                                onPressed: () => _deleteCategory(categoryId, categoryName),
                                tooltip: 'Excluir Categoria',
                              )
                            : Tooltip( // Adiciona tooltip para 'Geral'
                                message: 'Categoria padrão não pode ser excluída',
                                child: Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant.withAlpha((0.5 * 255).round())), // Corrigido de withOpacity
                              ),
                      ),
                    );
                  },
                ),
      // ✅ Adicionado FAB para adicionar categoria
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        tooltip: 'Adicionar Categoria',
        backgroundColor: colorScheme.secondary,
        child: Icon(Icons.add, color: colorScheme.onSecondary),
      ),
    );
  }
}

