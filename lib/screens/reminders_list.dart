import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import 'add_reminder.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
import '../database/category_helper.dart';
import 'checklist_screen.dart';
import '../widgets/unified_drawer.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import '../services/app_state_service.dart';
import '../services/pix_suggestion_service.dart';
import '../widgets/pix_suggestion_dialog.dart';

class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper();
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
  late StreamSubscription<DataChangeEvent> _dataSubscription;
  late StreamSubscription<LoadingState> _loadingSubscription;
  bool _isImporting = false;

  // ✅ NOVO: Controle do modo rápido para checklists
  final Set<int> _quickModeActiveChecklists = {};

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
    _setupDataListener();
    _setupLoadingListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dataSubscription.cancel();
    _loadingSubscription.cancel();
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
        tempCategoryColorMap[normalizedName] =
            _parseColorHex(colorHex, normalizedName);
      }

      if (!mounted) return;
      setState(() {
        _reminders = reminders
            .map((r) => r.copyWith(category: r.category.trim().toLowerCase()))
            .toList();
        _normalizedCategories = normalizedCategoriesSet.toList()..sort();
        _categoryColorMap = tempCategoryColorMap;

        if (_selectedCategory != null &&
            !_normalizedCategories.contains(_selectedCategory)) {
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
            reminder.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            (reminder.description
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()));

        final matchesCategory =
            _selectedCategory == null || reminder.category == _selectedCategory;

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
    final reminderDate = DateTime(
        reminder.dateTime.year, reminder.dateTime.month, reminder.dateTime.day);

    switch (_selectedDateFilter) {
      case 'today':
        return reminderDate.isAtSameMomentAs(today);
      case 'tomorrow':
        return reminderDate.isAtSameMomentAs(tomorrow);
      case 'week':
        return reminderDate.isAfter(today.subtract(const Duration(days: 1))) &&
            reminderDate.isBefore(weekEnd.add(const Duration(days: 1)));
      case 'custom':
        if (_selectedCustomDate == null) return false;
        final customDate = DateTime(_selectedCustomDate!.year,
            _selectedCustomDate!.month, _selectedCustomDate!.day);
        return reminderDate.isAtSameMomentAs(customDate);
      default:
        return true;
    }
  }

  int _getCountForDateFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    return _reminders.where((reminder) {
      if (reminder.isCompleted) return false; // Só conta pendentes

      final reminderDate = DateTime(reminder.dateTime.year,
          reminder.dateTime.month, reminder.dateTime.day);

      switch (filter) {
        case 'today':
          return reminderDate.isAtSameMomentAs(today);
        case 'tomorrow':
          return reminderDate.isAtSameMomentAs(tomorrow);
        case 'week':
          return reminderDate
                  .isAfter(today.subtract(const Duration(days: 1))) &&
              reminderDate.isBefore(weekEnd.add(const Duration(days: 1)));
        case 'custom':
          if (_selectedCustomDate == null) return false;
          final customDate = DateTime(_selectedCustomDate!.year,
              _selectedCustomDate!.month, _selectedCustomDate!.day);
          return reminderDate.isAtSameMomentAs(customDate);
        default:
          return false;
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

  // ✅ NOVO: Métodos para gerenciar checklist

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

  void _setupDataListener() {
    _dataSubscription = AppStateService().dataChanges.listen((event) {
      if (event.type == 'reminders' || event.type == 'all') {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _reloadDataSafely();
          }
        });
      }
    });
  }

  void _setupLoadingListener() {
    _loadingSubscription = AppStateService().loadingState.listen((state) {
      if (state.operation == 'backup_import') {
        if (mounted) {
          setState(() {
            _isImporting = state.isLoading;
          });
        }
      }
    });
  }

  Future<void> _reloadDataSafely() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await _loadReminders();
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
                  _selectedCategory =
                      categoryValue == 'all' ? null : categoryValue;
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
                    final Color color =
                        _categoryColorMap[normalizedCategory] ?? Colors.grey;
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
      body: Stack(
        children: [
          Column(
            children: [
              // ✅ FILTROS LIMPOS SEM ANIMAÇÃO
              if (_reminders.isNotEmpty) ...[
                Container(
                  height: 50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          if (_isImporting)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Importando backup...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aguarde enquanto restauramos seus dados',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      drawer: const UnifiedDrawer(
        currentScreen: 'reminders',
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = value == null
        ? _selectedDateFilter == null
        : _selectedDateFilter == value;

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

// ✅ Widget especial para checklists - Opção A: Espaçamento Inteligente
  Widget _buildChecklistItem(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue =
        reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
    final categoryNormalized = reminder.category;
    final categoryColor = _categoryColorMap[categoryNormalized] ?? Colors.grey;

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
                    : Colors.blue.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ListTile(
          onTap: () => _openChecklistScreen(reminder),
          onLongPress: () => _showReminderDetails(reminder),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Linha 1: Título e Badge
              Row(
                children: [
                  const Icon(
                    Icons.checklist,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      reminder.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        decoration: reminder.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: reminder.isCompleted
                            ? (isDark ? Colors.grey[600] : Colors.grey[500])
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

              const SizedBox(height: 12), // Espaçamento inteligente

              // ✅ Linha 2: Barra de Progresso
              Row(
                children: [
                  SizedBox(
                    width: 185, //Tamanho da barra
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: reminder.completionPercentage,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(reminder.completionPercentage * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12), //  Espaçamento inteligente

              //  Linha 3: Preview dos próximos items
              Row(
                children: [
                  Icon(
                    Icons.playlist_add_check,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reminder.nextItemsPreview,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                  height: 8), // ✅ Espaçamento menor para última linha

              //  Linha 4: Categoria e Data
              Row(
                children: [
                  if (categoryNormalized.isNotEmpty) ...[
                    Icon(
                      Icons.label,
                      size: 14,
                      color: categoryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      categoryNormalized,
                      style: TextStyle(
                        fontSize: 12,
                        color: categoryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(reminder.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Switch(
            value: reminder.notificationsEnabled && !reminder.isCompleted,
            onChanged: reminder.isCompleted
                ? null
                : (value) {
                    _toggleNotifications(reminder, value);
                  },
            activeColor: Colors.blue,
          ),
        ),
      ),
    );
  }

  // ✅ ALTERAÇÃO 3: MÉTODO _buildDrawer() REMOVIDO COMPLETAMENTE
  // O UnifiedDrawer agora faz esse trabalho

  Widget _buildReminderItem(Reminder reminder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue =
        reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reminder.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  decoration:
                      reminder.isCompleted ? TextDecoration.lineThrough : null,
                  color: reminder.isCompleted
                      ? (isDark ? Colors.grey[600] : Colors.grey[500])
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              // ✅ Categoria e Data - igual ao checklist
              Row(
                children: [
                  if (categoryNormalized.isNotEmpty) ...[
                    Icon(
                      Icons.label,
                      size: 14,
                      color: categoryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      categoryNormalized,
                      style: TextStyle(
                        fontSize: 12,
                        color: categoryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(reminder.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Switch(
            value: reminder.notificationsEnabled && !reminder.isCompleted,
            onChanged: reminder.isCompleted
                ? null
                : (value) {
                    _toggleNotifications(reminder, value);
                  },
            activeColor: Colors.blue,
          ),
        ),
      ),
    );
  }

// ✅ Método que estava faltando
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
                    const Icon(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                reminder.isCompleted
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                'Status',
                reminder.isCompleted ? 'Concluído' : 'Pendente',
                color: reminder.isCompleted ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.notifications,
                'Notificações',
                reminder.notificationsEnabled ? 'Ativadas' : 'Desativadas',
                color:
                    reminder.notificationsEnabled ? Colors.blue : Colors.grey,
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
                        reminder.isCompleted ? 'Reabrir' : 'Concluir',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            reminder.isCompleted ? Colors.orange : Colors.green,
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
                            builder: (context) =>
                                AddReminderScreen(reminderToEdit: reminder),
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

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? color}) {
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
            title: Text(
                'Excluir ${reminder.isChecklist ? 'checklist' : 'lembrete'}?'),
            content:
                Text('Tem certeza que deseja excluir "${reminder.title}"?'),
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
        ) ??
        false;
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
          content: Text(
              '${reminder.isChecklist ? 'Checklist' : 'Lembrete'} movido para a lixeira'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              await _databaseHelper.restoreReminder(reminder.id!);
              if (reminder.notificationsEnabled &&
                  !reminder.isCompleted &&
                  reminder.dateTime.isAfter(DateTime.now())) {
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
      
      // 🎯 NOVO: Sugerir PIX após completar lembrete
      _checkPixSuggestionAfterCompletion();
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

Future<void> _checkPixSuggestionAfterCompletion() async {
  try {
    await Future.delayed(const Duration(milliseconds: 800));
    
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