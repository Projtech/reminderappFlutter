import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // Import main.dart para acessar MyApp.of(context)
import '../models/reminder.dart';
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../services/notification_service.dart';
import 'add_reminder.dart';
import 'manage_categories_screen.dart'; // ADICIONADO: Import da tela de gerenciamento

class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryHelper _categoryHelper = CategoryHelper();
  List<Reminder> _reminders = [];
  Map<String, Color> _categoryColors = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadCategories();
    await _loadReminders();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      await _categoryHelper.ensureDefaultCategory(); // Garante que 'Geral' exista
      final categories = await _categoryHelper.getAllCategories();
      if (mounted) {
        setState(() {
          _categoryColors = {};
          for (final category in categories) {
            final name = category['name'] as String;
            final colorHex = category['color'] as String;
            try {
              _categoryColors[name] = Color(int.parse(colorHex, radix: 16));
            } catch (e) {
              debugPrint('Erro ao parsear cor $colorHex para categoria $name: $e');
              _categoryColors[name] = Colors.grey;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar categorias: $e');
    }
  }

  Future<void> _loadReminders() async {
    try {
      final reminders = await _databaseHelper.getAllReminders();
      if (mounted) {
        setState(() {
          _reminders = reminders;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar lembretes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor = theme.colorScheme.primary;
    final fabColor = theme.colorScheme.secondary;
    final iconColor = theme.colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: iconColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Lembretes',
          style: TextStyle(color: iconColor, fontSize: 20, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: iconColor),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            )
          : _reminders.isEmpty
              ? _buildEmptyState()
              : _buildRemindersList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditScreen(),
        backgroundColor: fabColor,
        child: Icon(Icons.add, color: theme.colorScheme.onSecondary),
      ),
    );
  }

  Widget _buildDrawer() {
    final myAppState = MyApp.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface, // Adapta cor do drawer ao tema
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primary,
            ),
            child: Text(
              'Configurações',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.category_outlined, color: colorScheme.onSurfaceVariant),
            title: Text('Gerenciar Categorias', style: TextStyle(color: colorScheme.onSurface)),
            onTap: () {
              Navigator.pop(context); // Fecha o drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
              ).then((_) {
                // Recarrega categorias e lembretes ao voltar, caso alguma categoria tenha sido excluída
                _loadData();
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('Modo Escuro', style: TextStyle(color: colorScheme.onSurface)),
            secondary: Icon(
              isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            value: isDarkMode,
            onChanged: (bool value) {
              myAppState?.changeTheme(value ? ThemeMode.dark : ThemeMode.light);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhum lembrete encontrado',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no + para adicionar seu primeiro lembrete',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return _buildDismissibleReminderCard(reminder, index);
        },
      ),
    );
  }

  Widget _buildDismissibleReminderCard(Reminder reminder, int index) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key(reminder.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text(
              'Excluir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(reminder);
      },
      onDismissed: (direction) async {
        await _deleteReminder(reminder, index);
      },
      child: _buildReminderCard(reminder),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final shadowColor = theme.shadowColor;
    final primaryTextColor = theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface.withOpacity(0.7);

    return GestureDetector(
      onTap: () => _navigateToAddEditScreen(reminderToEdit: reminder),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (reminder.description.isNotEmpty)
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(reminder.category),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reminder.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: secondaryTextColor),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(reminder.dateTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 12),
                if (reminder.isRecurring) ...[
                  Icon(Icons.repeat, size: 16, color: Colors.purple[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Mensal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      reminder.notificationsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      size: 18,
                      color: reminder.notificationsEnabled
                          ? Colors.green[600]
                          : secondaryTextColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: reminder.notificationsEnabled,
                        onChanged: (value) => _toggleNotifications(reminder, value),
                        activeColor: Colors.green,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddEditScreen({Reminder? reminderToEdit}) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddReminderScreen(reminderToEdit: reminderToEdit),
        ),
      );

      if (result != null && result is Reminder) {
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reminderToEdit == null
                  ? 'Lembrete "${result.title}" criado com sucesso!'
                  : 'Lembrete "${result.title}" atualizado com sucesso!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao navegar ou processar resultado de Add/Edit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocorreu um erro'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(Reminder reminder, bool enabled) async {
    try {
      final updatedReminder = Reminder(
        id: reminder.id,
        title: reminder.title,
        description: reminder.description,
        category: reminder.category,
        dateTime: reminder.dateTime,
        isCompleted: reminder.isCompleted,
        isRecurring: reminder.isRecurring,
        recurringType: reminder.recurringType,
        notificationsEnabled: enabled,
      );

      await _databaseHelper.updateReminder(updatedReminder);

      if (enabled) {
        // Cancela qualquer notificação antiga antes de agendar a nova
        if (reminder.id != null) {
          await NotificationService.cancelNotification(reminder.id!); 
        }
        if (reminder.isRecurring) {
          await NotificationService.scheduleRecurringNotification(
            id: reminder.id!,
            title: reminder.title,
            description: reminder.description,
            scheduledDate: reminder.getNextOccurrence(),
            category: reminder.category,
          );
        } else {
          await NotificationService.scheduleNotification(
            id: reminder.id!,
            title: reminder.title,
            description: reminder.description,
            scheduledDate: reminder.dateTime,
            category: reminder.category,
          );
        }
      } else {
        if (reminder.id != null) {
          await NotificationService.cancelNotification(reminder.id!); // Cancela notificação
        }
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled
                ? 'Notificações ativadas para "${reminder.title}"'
                : 'Notificações desativadas para "${reminder.title}"'),
            backgroundColor: enabled ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao alternar notificações: $e');
    }
  }

  Future<bool> _showDeleteConfirmation(Reminder reminder) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text('Confirmar Exclusão', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('Tem certeza que deseja excluir o lembrete "${reminder.title}"?', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: theme.colorScheme.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    ) ?? false; // Retorna false se o diálogo for fechado sem clicar nos botões
  }

  Future<void> _deleteReminder(Reminder reminder, int index) async {
    try {
      await _databaseHelper.deleteReminder(reminder.id!); // Deleta do banco
      await NotificationService.cancelNotification(reminder.id!); // Cancela notificação

      // Remove da lista local para atualização visual imediata
      setState(() {
        _reminders.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lembrete "${reminder.title}" excluído.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao excluir lembrete: $e');
      // Se der erro, recarrega a lista do banco para garantir consistência
      await _loadData();
    }
  }

  Color _getCategoryColor(String categoryName) {
    return _categoryColors[categoryName] ?? Colors.grey; // Retorna cinza se a categoria não for encontrada
  }
}

