import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Importar Permission Handler
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/reminders_list.dart';
import 'my_notes_screen.dart'; // Importar a nova tela de anotações
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermissionIfNeeded();
    });
  }

  // --- FUNÇÃO CORRIGIDA PARA USAR OS NOVOS MÉTODOS DO NotificationService ---
  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Usar uma chave diferente para garantir que a nova lógica seja executada pelo menos uma vez
      bool alreadyRequested = prefs.getBool('notification_permission_requested_v3') ?? false;
      if (!mounted) return;

      if (!alreadyRequested) {
        debugPrint("HomeScreen: Requesting core permissions (Notification & Exact Alarm) for the first time.");
        // Chamar o novo método que usa permission_handler
        final Map<Permission, PermissionStatus> statuses = await NotificationService.requestCorePermissions();
        if (!mounted) return;

        // Marcar como solicitado
        await prefs.setBool('notification_permission_requested_v3', true);

        // Verificar os status retornados
        bool notificationGranted = statuses[Permission.notification]?.isGranted ?? false;
        bool alarmGranted = statuses[Permission.scheduleExactAlarm]?.isGranted ?? false;
        
        debugPrint("HomeScreen: Permission request finished. Notification Granted: $notificationGranted, Exact Alarm Granted: $alarmGranted");

        // Mostrar feedback ao usuário
        if (notificationGranted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de notificações concedida!'), backgroundColor: Colors.green),
          );
          if (!alarmGranted) {
             // Informar sobre alarme exato se necessário (opcional, pode ser confuso)
             // ScaffoldMessenger.of(context).showSnackBar(
             //   const SnackBar(content: Text('Permissão de alarme exato não concedida. Lembretes podem não ser precisos.'), backgroundColor: Colors.orange),
             // );
          }
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de notificações negada. Ative nas configurações para receber lembretes.'), backgroundColor: Colors.orange),
          );
          // Opcional: Tentar abrir as configurações se negado
          // await NotificationService.openSettingsAndRequestPermissions();
        }

      } else {
        debugPrint("HomeScreen: Core permissions already requested in a previous session. Checking current status...");
        // Opcional: Verificar status atual silenciosamente se já foi solicitado antes
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
        child: Padding(
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
      ),
    );
  }
}

