import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o serviço de notificação SEM pedir permissão ainda
  await NotificationService.initialize();

  // Carrega tema
  final prefs = await SharedPreferences.getInstance();
  final String? themeModeString = prefs.getString('theme_mode');
  ThemeMode initialThemeMode = (themeModeString == 'dark') ? ThemeMode.dark : ThemeMode.light;

  runApp(MyApp(initialThemeMode: initialThemeMode));
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
    // ✅ Pedir permissão de notificação após o primeiro frame (opcional, pode ser na HomeScreen)
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _requestNotificationPermissionIfNeeded();
    // });
  }

  // // Função para pedir permissão (pode ser movida para HomeScreen)
  // Future<void> _requestNotificationPermissionIfNeeded() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   bool alreadyRequested = prefs.getBool('notification_permission_requested') ?? false;
  //   if (!alreadyRequested) {
  //     await NotificationService.requestPermissionsIfNeeded();
  //     await prefs.setBool('notification_permission_requested', true);
  //   }
  // }

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

