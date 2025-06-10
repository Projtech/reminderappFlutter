import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/reminders_list.dart';
import 'my_notes_screen.dart';
import '../services/notification_service.dart';
import '../database/database_helper.dart'; // Só este import adicional

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppInBackground();
    });
  }

  Future<void> _initializeAppInBackground() async {
    try {
      debugPrint('HomeScreen: Starting background initialization...');
      
      await NotificationService.initialize();
      await _recheckRecurringRemindersOnStartup();
      await _requestNotificationPermissionIfNeeded();
      
      debugPrint('HomeScreen: Background initialization completed');
    } catch (e) {
      debugPrint('HomeScreen: Error in background initialization: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _recheckRecurringRemindersOnStartup() async {
    try {
      final databaseHelper = DatabaseHelper();
      final recurringReminders = await databaseHelper.getRecurringRemindersNeedingReschedule();
      
      if (recurringReminders.isEmpty) {
        debugPrint("✅ Startup: Nenhum lembrete recorrente precisa reagendar");
        return;
      }
      
      int reagendados = 0;
      for (final reminder in recurringReminders) {
        if (reminder.notificationsEnabled && !reminder.isCompleted) {
          try {
            await NotificationService.cancelReminderNotifications(reminder.id!);
            final success = await NotificationService.scheduleReminderNotifications(reminder);
            
            if (success) {
              reagendados++;
              debugPrint("✅ Reagendado: ${reminder.title}");
            }
          } catch (e) {
            debugPrint("❌ Erro ao reagendar ${reminder.title}: $e");
          }
        }
      }
      
      if (reagendados > 0) {
        debugPrint("🔄 STARTUP SEGURO: $reagendados lembretes reagendados");
      }
      
    } catch (e) {
      debugPrint("❌ ERRO CRÍTICO no reagendamento de startup: $e");
    }
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool alreadyRequested = prefs.getBool('notification_permission_requested_v3') ?? false;
      if (!mounted) return;

      if (!alreadyRequested) {
        debugPrint("HomeScreen: Requesting core permissions for the first time.");
        final Map<Permission, PermissionStatus> statuses = await NotificationService.requestCorePermissions();
        if (!mounted) return;

        await prefs.setBool('notification_permission_requested_v3', true);

        bool notificationGranted = statuses[Permission.notification]?.isGranted ?? false;
        
        if (notificationGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de notificações concedida!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de notificações negada. Ative nas configurações para receber lembretes.'), backgroundColor: Colors.orange),
          );
        }
      } else {
        debugPrint("HomeScreen: Permissions already requested. Checking status...");
        await NotificationService.checkNotificationPermissionStatus();
        await NotificationService.checkExactAlarmPermissionStatus();
      }
    } catch (e) {
       debugPrint("HomeScreen: Error requesting notification permission: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao solicitar permissão: $e'), backgroundColor: Colors.red),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 30.0, 20.0, 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha((0.2 * 255).round()),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ]
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 60,
                      color: colorScheme.onPrimary,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    'Seus Lembretes',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Organize seus compromissos e não perca mais nada.',
                     style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RemindersListScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.list_alt_rounded, size: 24),
                      label: Text(
                        'Ver Meus Lembretes',
                        style: theme.textTheme.labelLarge?.copyWith(
                           color: colorScheme.onPrimary,
                           fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyNotesScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.notes_rounded, size: 24),
                      label: Text(
                        'Ver Minhas Anotações',
                        style: theme.textTheme.labelLarge?.copyWith(
                           color: colorScheme.onPrimary,
                           fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      'Desenvolvido por @ProjTech',
                      style: theme.textTheme.bodySmall?.copyWith(
                         color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isInitializing)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Inicializando...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}