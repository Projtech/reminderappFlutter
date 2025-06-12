import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import '../database/category_helper.dart';
import 'package:intl/intl.dart';

class RemindersTrashScreen extends StatefulWidget {
  const RemindersTrashScreen({super.key});

  @override
  State<RemindersTrashScreen> createState() => _RemindersTrashScreenState();
}

class _RemindersTrashScreenState extends State<RemindersTrashScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper();
  final TextEditingController _searchController = TextEditingController();
  
  List<Reminder> _deletedReminders = [];
  List<Reminder> _filteredReminders = [];
  bool _isLoading = true;
  bool _isSearching = false;
  Map<String, Color> _categoryColorMap = {};

  @override
  void initState() {
    super.initState();
    _loadDeletedReminders();
    _loadCategoryColors();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterReminders();
  }

  Future<void> _loadCategoryColors() async {
    try {
      final categories = await _categoryHelper.getAllCategories();
      final Map<String, Color> colorMap = {};

      for (final cat in categories) {
        final name = (cat['name'] as String).toLowerCase();
        final colorHex = cat['color'] as String;
        
        try {
          Color color = Colors.grey;
          if (colorHex.length == 6) {
            color = Color(int.parse('FF$colorHex', radix: 16));
          } else if (colorHex.length == 8) {
            color = Color(int.parse(colorHex, radix: 16));
          }
          colorMap[name] = color;
        } catch (e) {
          colorMap[name] = Colors.grey;
        }
      }

      if (mounted) {
        setState(() {
          _categoryColorMap = colorMap;
        });
      }
    } catch (e) {
      // Error loading colors, use defaults
    }
  }

  Future<void> _loadDeletedReminders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final deletedReminders = await _databaseHelper.getDeletedReminders();
      if (mounted) {
        setState(() {
          _deletedReminders = deletedReminders;
          _isLoading = false;
        });
        _filterReminders();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterReminders() {
    if (!mounted) return;

    List<Reminder> filtered = List.from(_deletedReminders);

    // Filtro por pesquisa
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered
          .where((reminder) =>
              reminder.title.toLowerCase().contains(searchTerm) ||
              reminder.description.toLowerCase().contains(searchTerm) ||
              reminder.category.toLowerCase().contains(searchTerm))
          .toList();
    }

    setState(() {
      _filteredReminders = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Pesquisar na lixeira...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : const Text('🗑️ Lixeira de Lembretes'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _filterReminders();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          if (_deletedReminders.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'empty_trash':
                    await _showEmptyTrashConfirmation();
                    break;
                  case 'clean_old':
                    await _showCleanOldConfirmation();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'empty_trash',
                  child: ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: Text('Esvaziar Lixeira'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'clean_old',
                  child: ListTile(
                    leading: Icon(Icons.auto_delete, color: Colors.orange),
                    title: Text('Limpar Antigos (30+ dias)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReminders.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Header com informações
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Itens na lixeira: ${_filteredReminders.length}. '
                              'Toque para restaurar ou deslize para excluir permanentemente.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lista de lembretes deletados
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _filteredReminders.length,
                        itemBuilder: (context, index) {
                          return _buildDeletedReminderItem(_filteredReminders[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'Nenhum item encontrado na lixeira'
                : 'Lixeira vazia',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Tente pesquisar com outros termos'
                : 'Lembretes excluídos aparecerão aqui',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedReminderItem(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryNormalized = reminder.category.toLowerCase();
    final categoryColor = _categoryColorMap[categoryNormalized] ?? Colors.grey;
    
    // Calcular há quanto tempo foi deletado
    final deletedAgo = reminder.deletedAt != null 
        ? _getTimeAgoText(reminder.deletedAt!)
        : 'Data desconhecida';

    return Dismissible(
      key: Key('deleted_${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Excluir\nPermanentemente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showPermanentDeleteConfirmation(reminder);
      },
      onDismissed: (direction) {
        _deletePermanently(reminder);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  reminder.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIXEIRA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reminder.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  reminder.description,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Excluído $deletedAgo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reminder.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Era para: ${DateFormat('dd/MM/yyyy HH:mm').format(reminder.dateTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.restore,
              color: Colors.blue,
              size: 24,
            ),
            onPressed: () => _restoreReminder(reminder),
            tooltip: 'Restaurar lembrete',
          ),
          onTap: () => _showDeletedReminderDetails(reminder),
        ),
      ),
    );
  }

  String _getTimeAgoText(DateTime deletedAt) {
    final now = DateTime.now();
    final difference = now.difference(deletedAt);

    if (difference.inDays > 0) {
      return 'há ${difference.inDays} dia${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'há ${difference.inHours} hora${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'há ${difference.inMinutes} minuto${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'há poucos segundos';
    }
  }

  void _showDeletedReminderDetails(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryNormalized = reminder.category.toLowerCase();
    final categoryColor = _categoryColorMap[categoryNormalized] ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Badge da lixeira
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '🗑️ ITEM NA LIXEIRA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              reminder.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),

            if (reminder.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                reminder.description,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 16),

            _buildDetailRow(
              Icons.delete_outline,
              'Excluído em',
              reminder.deletedAt != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(reminder.deletedAt!)
                  : 'Data desconhecida',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),

            _buildDetailRow(
              Icons.calendar_today,
              'Data/Hora Original',
              DateFormat('dd/MM/yyyy HH:mm').format(reminder.dateTime),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),

            _buildDetailRow(
              Icons.category,
              'Categoria',
              reminder.category,
              color: categoryColor,
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _restoreReminder(reminder);
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final confirmed = await _showPermanentDeleteConfirmation(reminder);
                      if (confirmed) {
                        _deletePermanently(reminder);
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Excluir Permanentemente'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _restoreReminder(Reminder reminder) async {
    try {
      await _databaseHelper.restoreReminder(reminder.id!);
      
      // Reagendar notificação se necessário
      if (reminder.notificationsEnabled && 
          !reminder.isCompleted && 
          reminder.dateTime.isAfter(DateTime.now())) {
        // Importar o NotificationService se necessário
        // await NotificationService.scheduleNotification(...);
      }

      _loadDeletedReminders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lembrete "${reminder.title}" restaurado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao restaurar lembrete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showPermanentDeleteConfirmation(Reminder reminder) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Excluir Permanentemente?'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            children: [
              const TextSpan(text: 'O lembrete '),
              TextSpan(
                text: '"${reminder.title}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' será excluído permanentemente e ',
              ),
              const TextSpan(
                text: 'NÃO PODERÁ SER RECUPERADO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deletePermanently(Reminder reminder) async {
    try {
      await _databaseHelper.deleteReminderPermanently(reminder.id!);
      _loadDeletedReminders();

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lembrete "${reminder.title}" excluído permanentemente'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir permanentemente: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEmptyTrashConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Esvaziar Lixeira?'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            children: [
              TextSpan(
                text: 'TODOS os ${_deletedReminders.length} lembretes da lixeira',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' serão '),
              const TextSpan(
                text: 'EXCLUÍDOS PERMANENTEMENTE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const TextSpan(text: ' e não poderão ser recuperados.'),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Esvaziar Lixeira'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.emptyTrash();
        _loadDeletedReminders();

        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lixeira esvaziada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao esvaziar lixeira: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCleanOldConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧹 Limpar Itens Antigos?'),
        content: const Text(
          'Esta ação irá excluir permanentemente todos os lembretes que estão na lixeira há mais de 30 dias.\n\n'
          'Esta ação não pode ser desfeita.'
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpar Antigos'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final deletedCount = await _databaseHelper.cleanOldDeletedReminders(30);
        _loadDeletedReminders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deletedCount lembretes antigos foram excluídos permanentemente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao limpar itens antigos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}