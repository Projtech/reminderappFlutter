import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'database/database_helper.dart'; // ✅ ADICIONAR

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o serviço de notificação SEM pedir permissão ainda
  await NotificationService.initialize();

  // ✅ VERIFICAÇÃO CRÍTICA DE SEGURANÇA - SEMPRE EXECUTA
  await _recheckRecurringRemindersOnStartup();

  // Carrega tema
  final prefs = await SharedPreferences.getInstance();
  final String? themeModeString = prefs.getString('theme_mode');
  ThemeMode initialThemeMode = (themeModeString == 'dark') ? ThemeMode.dark : ThemeMode.light;

  runApp(MyApp(initialThemeMode: initialThemeMode));
}

// ✅ FUNÇÃO DE SEGURANÇA CRÍTICA
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
          // Cancelar notificações antigas
          await NotificationService.cancelReminderNotifications(reminder.id!);
          
          // Reagendar com as próximas ocorrências
          final success = await NotificationService.scheduleReminderNotifications(reminder);
          
          if (success) {
            reagendados++;
            debugPrint("✅ Reagendado: ${reminder.title} (${reminder.getRecurrenceDescription()})");
          }
        } catch (e) {
          debugPrint("❌ Erro ao reagendar ${reminder.title}: $e");
        }
      }
    }
    
    if (reagendados > 0) {
      debugPrint("🔄 STARTUP SEGURO: $reagendados de ${recurringReminders.length} lembretes reagendados");
    }
    
  } catch (e) {
    debugPrint("❌ ERRO CRÍTICO no reagendamento de startup: $e");
    // Em produção, você pode querer reportar este erro
  }
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, required this.initialThemeMode});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  Future<void> changeTheme(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', themeMode == ThemeMode.dark ? 'dark' : 'light');
  }
  
  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      useMaterial3: true,
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
        primary: Colors.blue[300],
        secondary: Colors.tealAccent[100],
        surface: const Color(0xFF1E1E1E), // Usar surface
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white, // Usar onSurface
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
         backgroundColor: Colors.blue[300],
         foregroundColor: Colors.black,
      ),
      drawerTheme: const DrawerThemeData(),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue[300];
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue[300]?.withAlpha(128); // Corrigido de withOpacity(0.5)
          }
          return null;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
           if (!states.contains(WidgetState.selected)) {
             return Colors.grey[600];
           }
           return null;
        }),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Lembretes',
      navigatorKey: MyApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      // ✅ A HomeScreen agora será responsável por pedir a permissão
      home: const HomeScreen(),
    );
  }
}