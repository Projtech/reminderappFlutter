import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import '../screens/add_reminder.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';

class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  List<Reminder> _reminders = [];
  List<Reminder> _filteredReminders = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
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

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await _databaseHelper.getAllReminders();
      final categories = <String>{};
      
      for (final reminder in reminders) {
        categories.add(reminder.category);
      }
      
      setState(() {
        _reminders = reminders;
        _categories = categories.toList()..sort();
        _sortReminders();
        _filterReminders();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _sortReminders() {
    _reminders.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return a.dateTime.compareTo(b.dateTime);
    });
  }

  void _filterReminders() {
    setState(() {
      _filteredReminders = _reminders.where((reminder) {
        final matchesSearch = _searchController.text.isEmpty ||
            reminder.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            reminder.description.toLowerCase().contains(_searchController.text.toLowerCase());
        
        final matchesCategory = _selectedCategory == null || 
            reminder.category == _selectedCategory;
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Pesquisar lembretes...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                  border: InputBorder.none,
                ),
              )
            : const Text(
                'Lembretes',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (category) {
                setState(() {
                  _selectedCategory = category == 'all' ? null : category;
                  _filterReminders();
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('Todas as categorias'),
                ),
                const PopupMenuDivider(),
                ..._categories.map((category) => PopupMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(category),
                    ],
                  ),
                )),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Cards de estatísticas
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Hoje',
                    _getTodayCount(),
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Esta Semana',
                    _getWeekCount(),
                    Icons.date_range,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Atrasados',
                    _getOverdueCount(),
                    Icons.warning,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    _getActiveCount(),
                    Icons.archive,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de lembretes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReminders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _filteredReminders.length,
                        itemBuilder: (context, index) {
                          final reminder = _filteredReminders[index];
                          return _buildReminderItem(reminder);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderItem(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
    
    return Dismissible(
      key: Key(reminder.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(reminder);
      },
      onDismissed: (direction) {
        _deleteReminder(reminder);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: reminder.isCompleted 
                ? Colors.green.withOpacity(0.3)
                : isOverdue 
                    ? Colors.red.withOpacity(0.3)
                    : Colors.transparent,
            width: 1,
          ),
        ),
        child: ListTile(
          onTap: () => _showReminderDetails(reminder),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            reminder.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
              color: reminder.isCompleted 
                  ? (isDark ? Colors.grey[600] : Colors.grey[500])
                  : null,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(reminder.category).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reminder.category,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getCategoryColor(reminder.category),
                  ),
                ),
              ),
            ],
          ),
          trailing: Switch(
            value: reminder.notificationsEnabled && !reminder.isCompleted,
            onChanged: reminder.isCompleted ? null : (value) {
              _toggleNotifications(reminder, value);
            },
            activeColor: Colors.blue,
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'trabalho':
        return Colors.blue;
      case 'pessoal':
        return Colors.purple;
      case 'estudos':
        return Colors.orange;
      case 'saúde':
        return Colors.green;
      case 'finanças':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'Nenhum lembrete encontrado'
                : 'Nenhum lembrete criado',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[600] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showReminderDetails(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (reminder.description.isNotEmpty) ...[
                Text(
                  'Descrição',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reminder.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
              ],
              
              _buildDetailRow(
                Icons.access_time,
                'Data e Hora',
                DateFormat('dd/MM/yyyy - HH:mm').format(reminder.dateTime),
              ),
              const SizedBox(height: 12),
              
              _buildDetailRow(
                Icons.category,
                'Categoria',
                reminder.category,
                color: _getCategoryColor(reminder.category),
              ),
              const SizedBox(height: 12),
              
              _buildDetailRow(
                reminder.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                'Status',
                reminder.isCompleted ? 'Concluído' : 'Pendente',
                color: reminder.isCompleted ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 12),
              
              _buildDetailRow(
                Icons.notifications,
                'Notificações',
                reminder.notificationsEnabled ? 'Ativadas' : 'Desativadas',
                color: reminder.notificationsEnabled ? Colors.blue : Colors.grey,
              ),
              
              if (reminder.isRecurring) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.repeat,
                  'Repetição',
                  'Mensal',
                  color: Colors.purple,
                ),
              ],
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleComplete(reminder);
                      },
                      icon: Icon(
                        reminder.isCompleted 
                            ? Icons.circle_outlined 
                            : Icons.check_circle,
                      ),
                      label: Text(
                        reminder.isCompleted 
                            ? 'Reabrir' 
                            : 'Concluir',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: reminder.isCompleted 
                            ? Colors.orange 
                            : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(reminder).then((confirm) {
                          if (confirm == true) {
                            _deleteReminder(reminder);
                          }
                        });
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Excluir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  int _getTodayCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _reminders.where((r) {
      final reminderDate = DateTime(
        r.dateTime.year,
        r.dateTime.month,
        r.dateTime.day,
      );
      return !reminderDate.isBefore(today) && 
             reminderDate.isBefore(weekFromNow) && 
             !r.isCompleted;
    }).length;
  }

  int _getOverdueCount() {
    final now = DateTime.now();
    return _reminders.where((r) => r.dateTime.isBefore(now) && !r.isCompleted).length;
  }

  int _getActiveCount() {
    return _reminders.where((r) => !r.isCompleted).length;
  }

  Future<bool> _showDeleteConfirmation(Reminder reminder) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lembrete?'),
        content: Text('Tem certeza que deseja excluir "${reminder.title}"?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _addReminder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddReminderScreen(),
      ),
    );
    if (result == true) {
      _loadReminders();
    }
  }

  void _deleteReminder(Reminder reminder) async {
    await _databaseHelper.deleteReminder(reminder.id!);
    await NotificationService.cancelNotification(reminder.id!);
    
    _loadReminders();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lembrete excluído'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              await _databaseHelper.insertReminder(reminder);
              _loadReminders();
            },
          ),
        ),
      );
    }
  }

  void _toggleComplete(Reminder reminder) async {
    final updated = reminder.copyWith(isCompleted: !reminder.isCompleted);
    await _databaseHelper.updateReminder(updated);
    
    if (updated.isCompleted) {
      await NotificationService.cancelNotification(reminder.id!);
    } else if (updated.notificationsEnabled) {
      await NotificationService.scheduleNotification(
        id: updated.id!,
        title: updated.title,
        description: updated.description,
        scheduledDate: updated.dateTime,
        category: updated.category,
      );
    }
    
    _loadReminders();
  }

  void _toggleNotifications(Reminder reminder, bool enabled) async {
    HapticFeedback.lightImpact();
    
    final updated = reminder.copyWith(notificationsEnabled: enabled);
    await _databaseHelper.updateReminder(updated);
    
    if (enabled && !reminder.isCompleted) {
      await NotificationService.scheduleNotification(
        id: reminder.id!,
        title: reminder.title,
        description: reminder.description,
        scheduledDate: reminder.dateTime,
        category: reminder.category,
      );
    } else {
      await NotificationService.cancelNotification(reminder.id!);
    }
    
    _loadReminders();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Notificações ativadas' : 'Notificações desativadas',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}