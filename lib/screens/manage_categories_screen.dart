import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
    // 1. Verificar se é a última categoria
    if (_categories.length <= 1) {
      _showMessage('Não é possível excluir a última categoria.', Colors.orange);
      return;
    }

    // 2. Verificar se há lembretes associados
    try {
      final reminderCount = await _databaseHelper.getReminderCountByCategory(categoryName);
      if (reminderCount > 0) {
        _showMessage('Não é possível excluir: existem $reminderCount lembrete(s) nesta categoria.', Colors.orange);
        return;
      }
    } catch (e) {
      _showMessage('Erro ao verificar lembretes associados.', Colors.red);
      return;
    }

    // 3. Confirmar exclusão
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
      // 4. Excluir a categoria
      try {
        await _categoryHelper.deleteCategory(categoryId);
        _showMessage('Categoria "$categoryName" excluída com sucesso.', Colors.green);
        _loadCategories(); // Recarrega a lista
      } catch (e) {
        _showMessage('Erro ao excluir categoria.', Colors.red);
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
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
                    'Nenhuma categoria encontrada.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final categoryId = category['id'] as int;
                    final categoryName = category['name'] as String;
                    final colorHex = category['color'] as String;
                    Color color = Colors.grey;
                    try {
                      color = Color(int.parse(colorHex, radix: 16));
                    } catch (e) {
                      debugPrint('Erro ao parsear cor $colorHex para categoria $categoryName na lista: $e');
                    }

                    // Não permite excluir a categoria padrão 'Geral'
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
                          ),
                        ),
                        title: Text(categoryName, style: TextStyle(color: colorScheme.onSurface)),
                        trailing: canDelete
                            ? IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                                onPressed: () => _deleteCategory(categoryId, categoryName),
                                tooltip: 'Excluir Categoria',
                              )
                            : null, // Não mostra botão de excluir para 'Geral'
                      ),
                    );
                  },
                ),
    );
  }
}

