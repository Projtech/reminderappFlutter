// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/reminders_list.dart';
import 'my_notes_screen.dart';
import '../services/notification_service.dart';
import '../database/database_helper.dart';
import '../services/consent_service.dart';
import '../widgets/consent_dialog.dart';
import '../services/auth_service.dart';
import '../screens/auth_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
  
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isInitializing = true;
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAppInBackground();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isAppInBackground = true;
    } else if (state == AppLifecycleState.resumed && _isAppInBackground) {
      _isAppInBackground = false;
      _checkAuthenticationIfNeeded();
    }
  }

Future<void> _checkConsentIfNeeded() async {
  try {
    final consentService = ConsentService();
    final hasShownConsent = await consentService.hasShownConsent();
    
    if (!hasShownConsent && mounted) {
      // Aguardar um pouco para a tela carregar completamente
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false, // Não pode fechar clicando fora
          builder: (context) => ConsentDialog(
            onConsentGiven: (accepted) async {
              await consentService.saveConsent(accepted);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      accepted 
                        ? '✅ Obrigado! Isso nos ajuda a melhorar o app.'
                        : '👍 Sem problemas! O app funciona normalmente.',
                    ),
                    backgroundColor: accepted ? Colors.green : Colors.blue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        );
      }
    }
  } catch (e) {
    // Error handled silently
  }
}

Future<void> _checkAuthenticationIfNeeded() async {
  try {
    // Verificar se segurança está habilitada
    final isSecurityEnabled = await AuthService.isSecurityEnabled();
    if (!isSecurityEnabled) return;
    
    // Verificar se precisa autenticar
    final needsAuth = await AuthService.needsAuthentication();
    if (!needsAuth) return;
    
    if (mounted) {
      // Mostrar tela de autenticação
      final authenticated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const AuthScreen(),
          settings: const RouteSettings(name: '/auth'),
        ),
      );
      
      // Se não autenticou, tentar fechar gracefully
      if (authenticated != true && mounted) {
        // Dar uma chance antes de fechar
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          SystemNavigator.pop();
        }
      }
    }
  } catch (e) {
    // Error handled silently
  }
}

Future<void> _initializeAppInBackground() async {
  try {
    await Future.delayed(const Duration(milliseconds: 100));
    
    await NotificationService.initialize();
    await Future.delayed(const Duration(milliseconds: 10));
    
    await _recheckRecurringRemindersOnStartup();
    await Future.delayed(const Duration(milliseconds: 10));
    
    await _requestNotificationPermissionIfNeeded();
    
    // ✅ NOVO: Verificar consentimento LGPD
    await _checkConsentIfNeeded();
    
    // ✅ NOVO: Verificar autenticação de segurança
    await _checkAuthenticationIfNeeded();
    
  } catch (e) {
    // Error handled silently
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
      return;
    }
    
    for (final reminder in recurringReminders) {
      if (reminder.notificationsEnabled && !reminder.isCompleted) {
        try {
          await NotificationService.cancelReminderNotifications(reminder.id!);
          await NotificationService.scheduleReminderNotifications(reminder);
          
          // Breathing space for UI
          await Future.delayed(const Duration(milliseconds: 5));
        } catch (e) {
          // Error handled silently
        }
      }
    }
    
  } catch (e) {
    // Error handled silently
  }
}

  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool alreadyRequested = prefs.getBool('notification_permission_requested_v3') ?? false;
      if (!mounted) return;

      if (!alreadyRequested) {
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
        await NotificationService.checkNotificationPermissionStatus();
        await NotificationService.checkExactAlarmPermissionStatus();
      }
    } catch (e) {
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
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(180),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Iniciando...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 11,
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