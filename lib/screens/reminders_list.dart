// lib/screens/reminders_list.dart - PARTE 1
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import '../models/checklist_item.dart';
import 'add_reminder.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import 'package:intl/intl.dart';
import 'manage_categories_screen.dart';
import '../database/category_helper.dart';
import '../main.dart';
import 'reminders_trash_screen.dart';
import 'checklist_screen.dart';

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
  String? _selectedCategory;
  String? _selectedDateFilter;
  DateTime? _selectedCustomDate;
  List<String> _normalizedCategories = [];
  Map<String, Color> _categoryColorMap = {};
  
  // ✅ NOVO: Controle do modo rápido para checklists
  Set<int> _quickModeActiveChecklists = {};

  DateTime get weekFromNow {
    final now = DateTime.now();
    final targetDate = now.add(const Duration(days: 7));
    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

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

  Future<void> _loadReminders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _databaseHelper.getAllReminders(),
        _categoryHelper.getAllCategories(),
      ]);

      final reminders = results[0] as List<Reminder>;
      final categoryData = results[1] as List<Map<String, dynamic>>;

      final normalizedCategoriesSet = <String>{};
      final tempCategoryColorMap = <String, Color>{};
      for (final catMap in categoryData) {
        final originalName = catMap['name'] as String? ?? '';
        final normalizedName = originalName.trim().toLowerCase();
        if (normalizedName.isEmpty) continue;

        final colorHex = catMap['color'] as String? ?? 'FF808080';
        normalizedCategoriesSet.add(normalizedName);
        tempCategoryColorMap[normalizedName] = _parseColorHex(colorHex, normalizedName);
      }

      if (!mounted) return;
      setState(() {
        _reminders = reminders.map((r) => r.copyWith(category: r.category.trim().toLowerCase())).toList();
        _normalizedCategories = normalizedCategoriesSet.toList()..sort();
        _categoryColorMap = tempCategoryColorMap;

        if (_selectedCategory != null && !_normalizedCategories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }

        _sortReminders();
        _filterReminders();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
            (reminder.description.toLowerCase().contains(_searchController.text.toLowerCase()));

        final matchesCategory = _selectedCategory == null ||
            reminder.category == _selectedCategory;

        final matchesDate = _matchesDateFilter(reminder);

        return matchesSearch && matchesCategory && matchesDate;
      }).toList();
    });
  }

  bool _matchesDateFilter(Reminder reminder) {
    if (_selectedDateFilter == null) return true;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));
    final reminderDate = DateTime(reminder.dateTime.year, reminder.dateTime.month, reminder.dateTime.day);
    
    switch (_selectedDateFilter) {
      case 'today': return reminderDate.isAtSameMomentAs(today);
      case 'tomorrow': return reminderDate.isAtSameMomentAs(tomorrow);
      case 'week': return reminderDate.isAfter(today.subtract(const Duration(days: 1))) && reminderDate.isBefore(weekEnd.add(const Duration(days: 1)));
      case 'custom':
        if (_selectedCustomDate == null) return false;
        final customDate = DateTime(_selectedCustomDate!.year, _selectedCustomDate!.month, _selectedCustomDate!.day);
        return reminderDate.isAtSameMomentAs(customDate);
      default: return true;
    }
  }

  int _getCountForDateFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    return _reminders.where((reminder) {
      if (reminder.isCompleted) return false; // Só conta pendentes
      
      final reminderDate = DateTime(reminder.dateTime.year, reminder.dateTime.month, reminder.dateTime.day);
      
      switch (filter) {
        case 'today': return reminderDate.isAtSameMomentAs(today);
        case 'tomorrow': return reminderDate.isAtSameMomentAs(tomorrow);
        case 'week': return reminderDate.isAfter(today.subtract(const Duration(days: 1))) && reminderDate.isBefore(weekEnd.add(const Duration(days: 1)));
        case 'custom':
          if (_selectedCustomDate == null) return false;
          final customDate = DateTime(_selectedCustomDate!.year, _selectedCustomDate!.month, _selectedCustomDate!.day);
          return reminderDate.isAtSameMomentAs(customDate);
        default: return false;
      }
    }).length;
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _selectedCustomDate = picked;
        _selectedDateFilter = 'custom';
        _filterReminders();
      });
    }
  }

  Future<void> _exportBackup() async {
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

  Future<void> _importBackup() async {
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

  // ✅ NOVO: Métodos para gerenciar checklist
  void _toggleQuickMode(int reminderId) {
    setState(() {
      if (_quickModeActiveChecklists.contains(reminderId)) {
        _quickModeActiveChecklists.remove(reminderId);
      } else {
        _quickModeActiveChecklists.add(reminderId);
      }
    });
  }

  void _toggleChecklistItem(Reminder reminder, int itemIndex) async {
    if (reminder.checklistItems == null || itemIndex >= reminder.checklistItems!.length) return;
    
    final updatedItems = List<ChecklistItem>.from(reminder.checklistItems!);
    updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
      isCompleted: !updatedItems[itemIndex].isCompleted,
    );
    
    final updatedReminder = reminder.copyWith(
      checklistItems: updatedItems,
    );
    
    try {
      await _databaseHelper.updateReminder(updatedReminder);
      _loadReminders();
      
      // Feedback háptico
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ NOVO: Navegar para tela completa do checklist
void _openChecklistScreen(Reminder reminder) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChecklistScreen(reminder: reminder),
    ),
  ).then((_) {
    _loadReminders(); // Recarregar quando voltar
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
            onSelected: (categoryValue) {
              setState(() {
                _selectedCategory = categoryValue == 'all' ? null : categoryValue;
                _filterReminders();
              });
            },
            itemBuilder: (context) {
               return [
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('Todas as categorias'),
                  ),
                  const PopupMenuDivider(),
                  ..._normalizedCategories.map((normalizedCategory) {
                    final Color color = _categoryColorMap[normalizedCategory] ?? Colors.grey;
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
        // ✅ FILTROS LIMPOS SEM ANIMAÇÃO
if (_reminders.isNotEmpty) ...[
  Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _buildFilterChip("Todos", null),
        const SizedBox(width: 12),
        _buildFilterChip("Hoje", "today"),
        const SizedBox(width: 12),
        _buildFilterChip("Amanhã", "tomorrow"),
        const SizedBox(width: 12),
        _buildFilterChip("Semana", "week"),
        const SizedBox(width: 12),
        _buildFilterChip("Data", "custom"),
      ],
    ),
  ),
],
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
                        // ✅ NOVO: Diferentes widgets para lembretes e checklists
                        return reminder.isChecklist 
                            ? _buildChecklistItem(reminder)
                            : _buildReminderItem(reminder);
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

Widget _buildFilterChip(String label, String? value) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isSelected = value == null ? _selectedDateFilter == null : _selectedDateFilter == value;
  
  final count = value == null ? 0 : _getCountForDateFilter(value);
  final displayText = value == null 
      ? label 
      : count > 0 
          ? "$label ($count)" 
          : label;
  
  return GestureDetector(
    onTap: () {
      if (value == null) {
        setState(() {
          _selectedDateFilter = null;
          _selectedCustomDate = null;
          _filterReminders();
        });
      } else if (value == 'custom') {
        _selectCustomDate();
      } else {
        setState(() {
          _selectedDateFilter = isSelected ? null : value;
          if (value != 'custom') _selectedCustomDate = null;
          _filterReminders();
        });
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color.fromARGB(255, 24, 102, 167)
            : (isDark ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected 
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

// ✅ NOVO: Widget especial para checklists
Widget _buildChecklistItem(Reminder reminder) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isOverdue = reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
  final categoryNormalized = reminder.category;
  final categoryColor = _categoryColorMap[categoryNormalized] ?? Colors.grey;
  final isQuickModeActive = _quickModeActiveChecklists.contains(reminder.id);

  return Dismissible(
    key: Key('checklist_${reminder.id}'),
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
                  : Colors.blue.withValues(alpha: 0.3), // ✅ Borda azul para checklists
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ✅ Header do checklist
          ListTile(
            onTap: () => _openChecklistScreen(reminder),
            onLongPress: () => _showReminderDetails(reminder),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.checklist,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                          color: reminder.isCompleted
                              ? (isDark ? Colors.grey[600] : Colors.grey[500])
                              : null,
                        ),
                      ),
                    ),
                    // ✅ Badge de progresso
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        reminder.checklistProgress,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ✅ Barra de progresso visual
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2, // ✅ DIMINUÍDO: era 4, agora 2
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1), // ✅ AJUSTADO: era 2, agora 1
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: reminder.completionPercentage,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1), // ✅ AJUSTADO: era 2, agora 1
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(reminder.completionPercentage * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10, // ✅ DIMINUÍDO: era 11, agora 10
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ✅ Preview dos próximos items
                Text(
                  'Próximos: ${reminder.nextItemsPreview}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (categoryNormalized.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(reminder.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ Botão de modo rápido
                GestureDetector(
                  onTap: () => _toggleQuickMode(reminder.id!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // ✅ AUMENTADO: era 8,4 agora 12,6
                    decoration: BoxDecoration(
                      color: isQuickModeActive 
                          ? Colors.orange 
                          : Colors.blue,
                      borderRadius: BorderRadius.circular(8), // ✅ AUMENTADO: era 6, agora 8
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isQuickModeActive ? Icons.close : Icons.flash_on,
                          color: Colors.white,
                          size: 16, // ✅ AUMENTADO: era 14, agora 16
                        ),
                        const SizedBox(width: 6), // ✅ AUMENTADO: era 4, agora 6
                        Text(
                          isQuickModeActive ? 'Sair' : 'Rápido',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12, // ✅ AUMENTADO: era 11, agora 12
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Switch(
                  value: reminder.notificationsEnabled && !reminder.isCompleted,
                  onChanged: reminder.isCompleted ? null : (value) {
                    _toggleNotifications(reminder, value);
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),
          // ✅ Modo rápido expandido
          if (isQuickModeActive && reminder.checklistItems != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo Rápido - Toque para marcar/desmarcar',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reminder.checklistItems!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return GestureDetector(
                        onTap: () => _toggleChecklistItem(reminder, index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: item.isCompleted 
                                ? Colors.green.withValues(alpha: 0.2)
                                : (isDark ? Colors.grey[800] : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: item.isCompleted 
                                  ? Colors.green 
                                  : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                size: 16,
                                color: item.isCompleted ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    fontSize: 13,
                                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                    color: item.isCompleted 
                                        ? Colors.green
                                        : (isDark ? Colors.white : Colors.black),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
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
          
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text("Lixeira"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RemindersTrashScreen()),
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
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
                    
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Desativar otimização de bateria'),
            subtitle: const Text('Desabilitar otimização de bateria'),
            onTap: () async {
              Navigator.pop(context);
              await NotificationService.requestBatteryOptimizationDisable();
            },
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReminderItem(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
    final categoryNormalized = reminder.category;
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reminder.title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                  color: reminder.isCompleted
                      ? (isDark ? Colors.grey[600] : Colors.grey[500])
                      : null,
                ),
              ),
              if (categoryNormalized.isNotEmpty) ...[
                const SizedBox(height: 4),
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
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(reminder.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[700],
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
    final categoryNormalized = reminder.category;
    final categoryColor = _categoryColorMap[categoryNormalized] ?? Colors.grey;

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
                  if (reminder.isChecklist)
                    Icon(
                      Icons.checklist,
                      color: Colors.blue,
                      size: 24,
                    ),
                  if (reminder.isChecklist) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (reminder.isChecklist)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reminder.checklistProgress,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
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

              if (reminder.description.isNotEmpty && !reminder.isChecklist) ...[
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

              if (reminder.isChecklist) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progresso do Checklist',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openChecklistScreen(reminder);
                      },
                      child: const Text('Ver Checklist'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: reminder.completionPercentage,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${reminder.completedItemsCount} de ${reminder.totalItemsCount} items concluídos (${(reminder.completionPercentage * 100).round()}%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
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
                categoryNormalized,
                color: categoryColor,
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

              if (reminder.isRecurring && !reminder.isChecklist) ...[
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
                      onPressed: () {Navigator.pop(context);
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
       title: Text('Excluir ${reminder.isChecklist ? 'checklist' : 'lembrete'}?'),
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

   // ✅ Limpar do modo rápido se estiver ativo
   _quickModeActiveChecklists.remove(reminder.id);

   _loadReminders();

   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('${reminder.isChecklist ? 'Checklist' : 'Lembrete'} movido para a lixeira'),
         action: SnackBarAction(
           label: 'Desfazer',
           onPressed: () async {
             await _databaseHelper.restoreReminder(reminder.id!);
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
     // ✅ Limpar do modo rápido se concluído
     _quickModeActiveChecklists.remove(reminder.id);
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
       if (reminder.isChecklist) {
         await NotificationService.scheduleReminderNotifications(updated);
       } else {
         await NotificationService.scheduleNotification(
           id: reminder.id!,
           title: reminder.title,
           description: reminder.description,
           scheduledDate: reminder.dateTime,
           category: reminder.category,
         );
       }
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
}