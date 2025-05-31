import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../database/database_helper.dart';
import '../database/category_helper.dart';
import '../services/notification_service.dart';
import 'add_reminder.dart';

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
    setState(() => _isLoading = true);
    await _loadCategories();
    await _loadReminders();
    setState(() => _isLoading = false);
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryHelper.getAllCategories();
      setState(() {
        _categoryColors = {};
        for (final category in categories) {
          final name = category['name'] as String;
          final colorHex = category['color'] as String;
          _categoryColors[name] = Color(int.parse(colorHex));
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar categorias: $e');
    }
  }

  Future<void> _loadReminders() async {
    try {
      final reminders = await _databaseHelper.getAllReminders();
      setState(() {
        _reminders = reminders;
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar lembretes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Lembretes',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _reminders.isEmpty 
              ? _buildEmptyState() 
              : _buildRemindersList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewReminder(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.white54,
          ),
          SizedBox(height: 20),
          Text(
            'Nenhum lembrete encontrado',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Toque no + para adicionar seu primeiro lembrete',
            style: TextStyle(
              color: Colors.white54,
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
    return Dismissible(
      key: Key(reminder.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
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
    return GestureDetector(
      onTap: () => _showReminderDetails(reminder),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95), // ✅ CORRIGIDO
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // ✅ CORRIGIDO
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Parte superior: Título e categoria
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (reminder.description.isNotEmpty)
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
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

            // Parte inferior: Indicadores e switch de notificação
            Row(
              children: [
                // Data e hora
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(reminder.dateTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(width: 12),

                // Indicador de repetição
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

                // Switch de notificação
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
                          : Colors.grey[500],
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

  // Adicionar novo lembrete
  Future<void> _addNewReminder() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddReminderScreen(),
        ),
      );

      if (result != null && result is Reminder) {
        final reminderId = await _databaseHelper.insertReminder(result);

        if (result.notificationsEnabled) {
          if (result.isRecurring) {
            await NotificationService.scheduleRecurringNotification(
              id: reminderId,
              title: result.title,
              description: result.description,
              scheduledDate: result.getNextOccurrence(),
              category: result.category,
            );
          } else {
            await NotificationService.scheduleNotification(
              id: reminderId,
              title: result.title,
              description: result.description,
              scheduledDate: result.dateTime,
              category: result.category,
            );
          }
        }

        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lembrete "${result.title}" criado com sucesso!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao adicionar lembrete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao criar lembrete'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Método para alternar notificações
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
        // Ativar notificação
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
        // Desativar notificação
        await NotificationService.cancelNotification(reminder.id!);
      }

      await _loadData();

      // Feedback visual
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

  void _showReminderDetails(Reminder reminder) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.54), // ✅ CORRIGIDO
      builder: (context) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3), // ✅ CORRIGIDO
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(reminder.category),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          reminder.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  // Indicadores de status
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Indicador de repetição
                      if (reminder.isRecurring)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1), // ✅ CORRIGIDO
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.withOpacity(0.3)), // ✅ CORRIGIDO
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.repeat, size: 16, color: Colors.purple[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Repete mensalmente',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Indicador de notificações
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: reminder.notificationsEnabled
                              ? Colors.green.withOpacity(0.1) // ✅ CORRIGIDO
                              : Colors.orange.withOpacity(0.1), // ✅ CORRIGIDO
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: reminder.notificationsEnabled
                                  ? Colors.green.withOpacity(0.3) // ✅ CORRIGIDO
                                  : Colors.orange.withOpacity(0.3)), // ✅ CORRIGIDO
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              reminder.notificationsEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              size: 16,
                              color: reminder.notificationsEnabled
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reminder.notificationsEnabled
                                  ? 'Notificações ativas'
                                  : 'Notificações desativadas',
                              style: TextStyle(
                                fontSize: 12,
                                color: reminder.notificationsEnabled
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  if (reminder.description.isNotEmpty) ...[
                    const Text(
                      'Descrição',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reminder.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Agendado para',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'pt_BR').format(reminder.dateTime),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('HH:mm').format(reminder.dateTime),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _editReminder(reminder);
                          },
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          label: const Text(
                            'Editar',
                            style: TextStyle(color: Colors.blue),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            final confirm = await _showDeleteConfirmation(reminder);
                            if (confirm == true) {
                              final index = _reminders.indexOf(reminder);
                              await _deleteReminder(reminder, index);
                            }
                          },
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text(
                            'Excluir',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(Reminder reminder) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Lembrete'),
        content: Text('Tem certeza que deseja excluir "${reminder.title}"?\n\nEsta ação não pode ser desfeita.'),
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
  }

  Future<void> _deleteReminder(Reminder reminder, int index) async {
    try {
      await NotificationService.cancelNotification(reminder.id!);
      await _databaseHelper.deleteReminder(reminder.id!);

      setState(() {
        _reminders.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${reminder.title} excluído'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () async {
                try {
                  final newId = await _databaseHelper.insertReminder(reminder);

                  if (reminder.notificationsEnabled) {
                    if (reminder.isRecurring) {
                      await NotificationService.scheduleRecurringNotification(
                        id: newId,
                        title: reminder.title,
                        description: reminder.description,
                        scheduledDate: reminder.getNextOccurrence(),
                        category: reminder.category,
                      );
                    } else {
                      await NotificationService.scheduleNotification(
                        id: newId,
                        title: reminder.title,
                        description: reminder.description,
                        scheduledDate: reminder.dateTime,
                        category: reminder.category,
                      );
                    }
                  }

                  await _loadData();
                } catch (e) {
                  debugPrint('❌ Erro ao restaurar lembrete: $e');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao excluir lembrete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir lembrete'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _editReminder(Reminder reminder) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddReminderScreen(reminderToEdit: reminder),
        ),
      );

      if (result != null && result is Reminder) {
        await NotificationService.cancelNotification(reminder.id!);
        await _databaseHelper.updateReminder(result);

        if (result.notificationsEnabled) {
          if (result.isRecurring) {
            await NotificationService.scheduleRecurringNotification(
              id: result.id!,
              title: result.title,
              description: result.description,
              scheduledDate: result.getNextOccurrence(),
              category: result.category,
            );
          } else {
            await NotificationService.scheduleNotification(
              id: result.id!,
              title: result.title,
              description: result.description,
              scheduledDate: result.dateTime,
              category: result.category,
            );
          }
        }

        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lembrete "${result.title}" atualizado!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao editar lembrete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao editar lembrete'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getCategoryColor(String category) {
    if (_categoryColors.containsKey(category)) {
      return _categoryColors[category]!;
    }

    // Cor padrão para a categoria inicial
    if (category == 'Adicione as categorias aqui') {
      return Colors.grey;
    }

    // Cores padrão para categorias conhecidas
    switch (category.toLowerCase()) {
      case 'trabalho':
      case 'work':
        return Colors.blue;
      case 'pessoal':
      case 'personal':
        return Colors.green;
      case 'saúde':
      case 'health':
        return Colors.red;
      case 'compras':
      case 'shopping':
        return Colors.orange;
      case 'família':
      case 'family':
        return Colors.purple;
      case 'estudo':
      case 'study':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}