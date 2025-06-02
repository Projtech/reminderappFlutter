import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importar SharedPreferences
import '../screens/reminders_list.dart';
import 'add_reminder.dart';
import '../services/notification_service.dart'; // Importar NotificationService

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    // ✅ Pedir permissão de notificação após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermissionIfNeeded();
    });
  }

  // ✅ Função para pedir permissão apenas uma vez
  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool alreadyRequested = prefs.getBool('notification_permission_requested_v2') ?? false;
      if (!mounted) return; // Check if the widget is still mounted

      if (!alreadyRequested) {
        debugPrint("HomeScreen: Requesting notification permissions for the first time.");
        final bool granted = await NotificationService.requestPermissionsIfNeeded();
        if (!mounted) return;
        await prefs.setBool('notification_permission_requested_v2', true);
        debugPrint("HomeScreen: Permission request finished. Granted: $granted");

        // Opcional: Mostrar um SnackBar informando o usuário
        // if (granted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(content: Text('Permissão de notificações concedida!'), backgroundColor: Colors.green),
        //   );
        // } else {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(content: Text('Permissão de notificações negada. Você pode ativá-la nas configurações.'), backgroundColor: Colors.orange),
        //   );
        // }
      } else {
        debugPrint("HomeScreen: Notification permissions already requested in a previous session.");
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
    // Obter o tema atual
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Usar cor de fundo do tema
      backgroundColor: colorScheme.surface, // Changed from background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 30.0, 20.0, 20.0), // Adjusted padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Ícone principal - Refinado com gradiente suave
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
                      color: colorScheme.primary.withAlpha((0.2 * 255).round()), // Corrigido de withOpacity(0.2)
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ]
                ),
                child: Icon(
                  Icons.notifications_active_outlined, // Ícone Outlined para um visual mais leve
                  size: 60,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(height: 30),

              // Título
              Text(
                'Seus Lembretes',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 10),

              // Subtítulo
              Text(
                'Organize seus compromissos e não perca mais nada.',
                 style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Botão principal - Estilo ligeiramente ajustado
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

              // Botão secundário (OutlinedButton) - Estilo ligeiramente ajustado
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddReminderScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                     padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                  label: Text(
                    'Criar Novo Lembrete',
                     style: theme.textTheme.labelLarge?.copyWith(
                       color: colorScheme.primary,
                       fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Nome da Empresa
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

