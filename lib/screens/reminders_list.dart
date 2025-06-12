import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import 'add_reminder.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import 'package:intl/intl.dart';
import 'manage_categories_screen.dart';
import '../database/category_helper.dart';
import '../main.dart';

enum DateFilter { todos, hoje, amanha, estaSemana, dataEspecifica }

class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper();
  final BackupService _backupService = BackupService();
  final TextEditingController _searchController = TextEditingController();
  List<Reminder> _reminders = [];
  List<Reminder> _filteredReminders = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _selectedCategoryFilter;
  Map<String, Color> _categoryColorMap = {};
  
  // ✅ NOVOS: Estados dos filtros de data
  DateFilter _selectedDateFilter = DateFilter.todos;
  DateTime? _specificDate;

  @override
  void initState() {
    super.initState();
    _loadReminders();
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

  Future<void> _loadReminders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final reminders = await _databaseHelper.getAllReminders();
      if (!mounted) return;
      
      setState(() {
        _reminders = reminders;
        _filterReminders();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar lembretes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ NOVA: Lógica de filtros atualizada
  void _filterReminders() {
    setState(() {
      _filteredReminders = _reminders.where((reminder) {
        // Filtro de busca por texto
        final searchTerm = _searchController.text.toLowerCase();
        final matchesSearch = searchTerm.isEmpty ||
            reminder.title.toLowerCase().contains(searchTerm) ||
            reminder.description.toLowerCase().contains(searchTerm) ||
            reminder.category.toLowerCase().contains(searchTerm);

        // Filtro por categoria
        final matchesCategory = _selectedCategoryFilter == null ||
            reminder.category.toLowerCase() == _selectedCategoryFilter!.toLowerCase();

        // ✅ NOVO: Filtro por data
        final matchesDate = _matchesDateFilter(reminder);

        return matchesSearch && matchesCategory && matchesDate;
      }).toList();
      _filteredReminders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // ✅ NOVA: Função para verificar se lembrete passa no filtro de data
  bool _matchesDateFilter(Reminder reminder) {
    final now = DateTime.now();
    final reminderDate = reminder.dateTime;
    
    switch (_selectedDateFilter) {
      case DateFilter.todos:
        return true;
        
      case DateFilter.hoje:
        return _isSameDay(reminderDate, now);
        
      case DateFilter.amanha:
        final tomorrow = now.add(const Duration(days: 1));
        return _isSameDay(reminderDate, tomorrow);
        
      case DateFilter.estaSemana:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return reminderDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
               reminderDate.isBefore(endOfWeek.add(const Duration(days: 1)));
               
      case DateFilter.dataEspecifica:
        return _specificDate != null && _isSameDay(reminderDate, _specificDate!);
    }
  }

  // ✅ NOVA: Função auxiliar para comparar datas
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  // ✅ NOVA: Contar lembretes por filtro
  int _getFilterCount(DateFilter filter) {
    return _reminders.where((reminder) {
      switch (filter) {
        case DateFilter.todos:
          return true;
        case DateFilter.hoje:
          return _isSameDay(reminder.dateTime, DateTime.now());
        case DateFilter.amanha:
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          return _isSameDay(reminder.dateTime, tomorrow);
        case DateFilter.estaSemana:
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          return reminder.dateTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                 reminder.dateTime.isBefore(endOfWeek.add(const Duration(days: 1)));
        case DateFilter.dataEspecifica:
          return _specificDate != null && _isSameDay(reminder.dateTime, _specificDate!);
      }
    }).length;
  }

  // ✅ NOVA: Seletor de data específica
  Future<void> _selectSpecificDate() async {
    DateTime tempDate = _specificDate ?? DateTime.now();
    
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
                    color: Colors.grey.withOpacity(0.3),
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
                    'Escolher Data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _specificDate = tempDate;
                        _selectedDateFilter = DateFilter.dataEspecifica;
                        _filterReminders();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: tempDate,
                minimumDate: DateTime.now().subtract(const Duration(days: 365)),
                maximumDate: DateTime.now().add(const Duration(days: 365 * 2)),
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

  // ✅ NOVO: Widget dos chips de filtro
  Widget _buildDateFilterChips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            'Todos',
            DateFilter.todos,
            _getFilterCount(DateFilter.todos),
            isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Hoje',
            DateFilter.hoje,
            _getFilterCount(DateFilter.hoje),
            isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Amanhã',
            DateFilter.amanha,
            _getFilterCount(DateFilter.amanha),
            isDark,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Esta Semana',
            DateFilter.estaSemana,
            _getFilterCount(DateFilter.estaSemana),
            isDark,
          ),
          const SizedBox(width: 8),
          _buildDatePickerChip(isDark),
        ],
      ),
    );
  }

  // ✅ NOVO: Chip individual de filtro
  Widget _buildFilterChip(String label, DateFilter filter, int count, bool isDark) {
    final isSelected = _selectedDateFilter == filter;
    
    return FilterChip(
      label: Text(
        count > 0 ? '$label ($count)' : label,
        style: TextStyle(
          color: isSelected 
              ? Colors.white 
              : (isDark ? Colors.grey[300] : Colors.grey[700]),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedDateFilter = filter;
          if (filter != DateFilter.dataEspecifica) {
            _specificDate = null;
          }
          _filterReminders();
        });
      },
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      selectedColor: const Color.fromARGB(144, 33, 149, 243),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.transparent,
        width: 1,
      ),
    );
  }

  // ✅ NOVO: Chip do seletor de data
  Widget _buildDatePickerChip(bool isDark) {
    final isSelected = _selectedDateFilter == DateFilter.dataEspecifica;
    final label = isSelected && _specificDate != null
        ? DateFormat('dd/MM').format(_specificDate!)
        : '📅';
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected 
              ? Colors.white 
              : (isDark ? Colors.grey[300] : Colors.grey[700]),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        _selectSpecificDate();
      },
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      selectedColor: Colors.blue,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.transparent,
        width: 1,
      ),
    );
  }

  Widget _buildReminderItem(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
    final categoryNormalized = reminder.category.toLowerCase();
    final categoryColor = _categoryColorMap[categoryNormalized] ?? Colors.grey;

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
                ? Colors.green.withValues(alpha: 0.3)
                : isOverdue
                    ? Colors.red.withValues(alpha: 0.3)
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categoria existente
              if (categoryNormalized.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    categoryNormalized,
                    style: TextStyle(
                      fontSize: 11,
                      color: categoryColor,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              // ✅ NOVO: Data de criação
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(reminder.createdAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
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
    final categoryNormalized = reminder.category.toLowerCase();
    final categoryColor = _categoryColorMap[categoryNormalized] ?? Colors.grey;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          reminder.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reminder.description.isNotEmpty) ...[
                Text(
                  reminder.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildDetailRow(
                Icons.calendar_today,
                'Data/Hora',
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
              const SizedBox(height: 12),

              // ✅ NOVO: Mostrar data de criação nos detalhes também
              _buildDetailRow(
                Icons.schedule,
                'Criado em',
                DateFormat('dd/MM/yyyy HH:mm').format(reminder.createdAt),
                color: Colors.grey,
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
                  reminder.getRecurrenceDescription(),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddReminderScreen(reminderToEdit: reminder),
                          ),
                        ).then((result) {
                          if (result == true) {
                            _loadReminders();
                          }
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("Editar"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
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
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
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
              if (reminder.notificationsEnabled && !reminder.isCompleted && reminder.dateTime.isAfter(DateTime.now())) {
                 await NotificationService.scheduleNotification(
                    id: reminder.id!,
                    title: reminder.title,
                    description: reminder.description,
                    scheduledDate: reminder.dateTime,
                    category: reminder.category,
                 );
              }
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
      if (updated.dateTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleNotification(
          id: updated.id!,
          title: updated.title,
          description: updated.description,
          scheduledDate: updated.dateTime,
          category: updated.category,
        );
      }
    }

    _loadReminders();
  }

  void _toggleNotifications(Reminder reminder, bool enabled) async {
    HapticFeedback.lightImpact();

    final updated = reminder.copyWith(notificationsEnabled: enabled);
    await _databaseHelper.updateReminder(updated);

    if (enabled && !reminder.isCompleted) {
      if (reminder.dateTime.isAfter(DateTime.now())) {
         await NotificationService.scheduleNotification(
           id: reminder.id!,
           title: reminder.title,
           description: reminder.description,
           scheduledDate: reminder.dateTime,
           category: reminder.category,
         );
      }
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

  Future<void> _exportBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Backup Completo'),
        content: const Text(
          'Esta ação irá exportar TODOS os seus dados:\n\n'
          '• Todos os lembretes\n'
          '• Todas as anotações\n'
          '• Todas as categorias\n\n'
          'Deseja continuar?'
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
            child: const Text('Exportar Tudo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _backupService.exportBackup(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro inesperado: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar Backup'),
        content: const Text(
          'Esta ação irá importar TODOS os dados do backup:\n\n'
          '• Todos os lembretes\n'
          '• Todas as anotações\n'
          '• Todas as categorias\n\n'
          '⚠️ ATENÇÃO: Dados existentes podem ser substituídos!\n\n'
          'Deseja continuar?'
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
            ),
            child: const Text('Importar Tudo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _backupService.importBackup(context);
        if (success && mounted) {
          await _loadReminders();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro inesperado: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
                'Seus Lembretes',
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
         PopupMenuButton<String>(
           onSelected: (value) {
             setState(() {
               _selectedCategoryFilter = value == 'all' ? null : value;
               _filterReminders();
             });
           },
           itemBuilder: (context) {
             return [
               const PopupMenuItem(
                 value: 'all',
                 child: Text('Todas as categorias'),
               ),
               ..._categoryColorMap.keys.map((normalizedCategory) {
                 final color = _categoryColorMap[normalizedCategory] ?? Colors.grey;
                 return PopupMenuItem(
                   value: normalizedCategory,
                   child: Row(
                     children: [
                       Container(
                         width: 12,
                         height: 12,
                         decoration: BoxDecoration(
                           color: color,
                           shape: BoxShape.circle,
                         ),
                       ),
                       const SizedBox(width: 8),
                       Text(normalizedCategory),
                     ],
                   ),
                 );
               }),
             ];
           },
         ),
       ],
     ),
     body: Column(
       children: [
         // ✅ NOVO: Chips de filtro de data
         _buildDateFilterChips(),
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
     drawer: _buildDrawer(),
   );
 }

 Widget _buildDrawer() {
   final isDark = Theme.of(context).brightness == Brightness.dark;
   return Drawer(
     child: ListView(
       padding: EdgeInsets.zero,
       children: <Widget>[
         DrawerHeader(
           decoration: BoxDecoration(
             color: isDark ? Colors.grey[800] : Colors.blue,
           ),
           child: const Text(
             'Configurações',
             style: TextStyle(
               color: Colors.white,
               fontSize: 24,
             ),
           ),
         ),
         
         ListTile(
           leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
           title: Text(isDark ? 'Modo Claro' : 'Modo Escuro'),
           trailing: Switch(
             value: isDark,
             onChanged: (value) {
               MyApp.of(context)?.changeTheme(value ? ThemeMode.dark : ThemeMode.light);
             },
           ),
           onTap: () {
             final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
             MyApp.of(context)?.changeTheme(newMode);
           },
         ),
         
         ListTile(
           leading: const Icon(Icons.category),
           title: const Text('Gerenciar Categorias'),
           onTap: () {
             Navigator.pop(context);
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
             ).then((_) {
               _loadReminders();
             });
           },
         ),
         
         const Divider(),
         
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: Text(
             'BACKUP',
             style: TextStyle(
               fontSize: 12,
               fontWeight: FontWeight.bold,
               color: isDark ? Colors.grey[400] : Colors.grey[600],
             ),
           ),
         ),
         
         ListTile(
           leading: const Icon(Icons.file_download),
           title: const Text("Importar Backup"),
           onTap: () {
             Navigator.pop(context);
             _importBackup(); 
           },
         ),
         
         ListTile(
           leading: const Icon(Icons.file_upload),
           title: const Text("Exportar Backup"),
           onTap: () {
             Navigator.pop(context);
             _exportBackup(); 
           },
         ),
         
         const Divider(),
         
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: Text(
             'NOTIFICAÇÕES',
             style: TextStyle(
               fontSize: 12,
               fontWeight: FontWeight.bold,
               color: isDark ? Colors.grey[400] : Colors.grey[600],
             ),
           ),
         ),
         
         ListTile(
           leading: const Icon(Icons.notifications_active),
           title: const Text('Autorizar Notificações'),
           onTap: () {
             Navigator.pop(context);
             NotificationService.openSettingsAndRequestPermissions();
           },
         ),
         
         ListTile(
           leading: const Icon(Icons.battery_saver),
           title: const Text('🔋 Desativar otimização de bateria'),
           subtitle: const Text('Desabilitar otimização de bateria'),
           onTap: () async {
             Navigator.pop(context);
             await NotificationService.requestBatteryOptimizationDisable();
           },
         ),
       ],
     ),
   );
 }
}