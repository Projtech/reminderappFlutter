import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import 'add_reminder.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
// Importa a tela de gerenciamento de categorias
import 'manage_categories_screen.dart';
// Importa o helper de categorias para buscar cores
import '../database/category_helper.dart';
// Importa o main para acessar a função de troca de tema
import '../main.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper(); // Adiciona helper de categoria
  final TextEditingController _searchController = TextEditingController();
  List<Reminder> _reminders = [];
  List<Reminder> _filteredReminders = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _selectedCategory; // Armazena o nome normalizado (lowercase, trimmed)
  List<String> _normalizedCategories = []; // Lista de nomes normalizados
  Map<String, Color> _categoryColorMap = {}; // Chave: nome normalizado

  // Getter to calculate the date exactly 7 days from now (start of that day)
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

  // Função auxiliar para garantir que o hex da cor tenha o alfa
  Color _parseColorHex(String hex, String categoryName) {
    String hexUpper = hex.toUpperCase().replaceAll('#', '');
    if (hexUpper.length == 6) {
      // Adiciona FF (alfa opaco) se não estiver presente
      hexUpper = 'FF$hexUpper';
    }
    if (hexUpper.length != 8) {
      debugPrint("*** ERRO: Hex inválido '$hex' para categoria '$categoryName'. Usando Cinza padrão. ***");
      return Colors.grey; // Retorna cinza se ainda for inválido
    }
    try {
      return Color(int.parse(hexUpper, radix: 16));
    } catch (e) {
      debugPrint("*** ERRO ao parsear hex '$hexUpper' para categoria '$categoryName': $e. Usando Cinza padrão. ***");
      return Colors.grey;
    }
  }

  Future<void> _loadReminders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    // debugPrint("[RemindersList] Iniciando _loadReminders..."); // Removido debug
    try {
      // Carrega lembretes e categorias em paralelo
      final results = await Future.wait([
        _databaseHelper.getAllReminders(),
        _categoryHelper.getAllCategories(),
      ]);

      final reminders = results[0] as List<Reminder>;
      final categoryData = results[1] as List<Map<String, dynamic>>;
      // debugPrint("[RemindersList] Categorias carregadas do DB: $categoryData"); // Removido debug

      // Processa categorias e cria o mapa de cores
      final normalizedCategoriesSet = <String>{};
      final tempCategoryColorMap = <String, Color>{};
      for (final catMap in categoryData) {
        final originalName = catMap['name'] as String? ?? '';
        final normalizedName = originalName.trim().toLowerCase();
        if (normalizedName.isEmpty) continue;

        final colorHex = catMap['color'] as String? ?? 'FF808080'; // Cinza padrão
        normalizedCategoriesSet.add(normalizedName);
        // *** CORREÇÃO: Usar função auxiliar para parsear e garantir alfa ***
        tempCategoryColorMap[normalizedName] = _parseColorHex(colorHex, normalizedName);
      }
      // debugPrint("[RemindersList] Mapa de cores final: $tempCategoryColorMap"); // Removido debug
      // debugPrint("[RemindersList] Nomes normalizados: ${normalizedCategoriesSet.toList()}"); // Removido debug

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
      // debugPrint("[RemindersList] _loadReminders concluído."); // Removido debug
    } catch (e) {
      debugPrint('*** ERRO FATAL ao carregar lembretes ou categorias: $e ***');
      if (!mounted) return;
      setState(() => _isLoading = false);
      // TODO: Mostrar mensagem de erro
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
            (reminder.description?.toLowerCase() ?? '').contains(_searchController.text.toLowerCase());

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
                // debugPrint("[RemindersList] Filtro selecionado: '$categoryValue'"); // Removido debug
                setState(() {
                  _selectedCategory = categoryValue == 'all' ? null : categoryValue;
                  _filterReminders();
                });
              },
              itemBuilder: (context) {
                 // debugPrint("[RemindersList] Construindo itens do menu de filtro..."); // Removido debug
                 // debugPrint("[RemindersList] Categorias normalizadas para menu: $_normalizedCategories"); // Removido debug
                 // debugPrint("[RemindersList] Mapa de cores para menu: $_categoryColorMap"); // Removido debug
                 return [
                    const PopupMenuItem(
                      value: 'all',
                      child: Text('Todas as categorias'),
                    ),
                    const PopupMenuDivider(),
                    ..._normalizedCategories.map((normalizedCategory) {
                      // *** CORREÇÃO: Usar cor padrão cinza se não encontrar ***
                      final Color color = _categoryColorMap[normalizedCategory] ?? Colors.grey;
                      // debugPrint("[RemindersList] Item do filtro: '$normalizedCategory', Cor encontrada: $color"); // Removido debug
                      return PopupMenuItem(
                        value: normalizedCategory,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color, // Cor já deve estar opaca
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
            leading: const Icon(Icons.file_download),
            title: const Text("Importar Backup"),
            onTap: () async {
              Navigator.pop(context);
              print("Importar Backup");
              // TODO: Implementar lógica de IMPORTAR backup
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text("Exportar Backup"),
            onTap: () async {
              Navigator.pop(context);
              print("Exportar Backup");
              // TODO: Implementar lógica de EXPORTAR backup
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Autorizar Notificações'),
            onTap: () {
              Navigator.pop(context);
              NotificationService.openSettingsAndRequestPermissions();
              print('Abrindo configurações de permissão...');
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
                _loadReminders(); // Recarrega ao voltar da tela de categorias
              });
            },
          ),
        ],
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
    final categoryNormalized = reminder.category;
    // *** CORREÇÃO: Usar cor padrão cinza se não encontrar ***
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
          subtitle: categoryNormalized.isNotEmpty
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.2),
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
                )
              : null,
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
    // *** CORREÇÃO: Usar cor padrão cinza se não encontrar ***
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

              if (reminder.description != null && reminder.description!.isNotEmpty) ...[
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
                  reminder.description!,
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
                        Navigator.pop(context); // Fecha o dialog
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
      return reminderDate.isAtSameMomentAs(today) && !r.isCompleted;
    }).length;
  }

  int _getWeekCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _reminders.where((r) {
      final reminderDate = DateTime(
        r.dateTime.year,
        r.dateTime.month,
        r.dateTime.day,
      );
      return reminderDate.isAfter(today) && reminderDate.isBefore(weekFromNow) && !r.isCompleted;
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
}

