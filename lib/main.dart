import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADICIONADO: Import shared_preferences
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Erro ao inicializar notificações: $e');
  }

  // ADICIONADO: Carregar tema antes de rodar o app
  final prefs = await SharedPreferences.getInstance();
  final String? themeModeString = prefs.getString('theme_mode');
  ThemeMode initialThemeMode;
  if (themeModeString == 'dark') {
    initialThemeMode = ThemeMode.dark;
  } else {
    initialThemeMode = ThemeMode.light; // Padrão é light
  }

  runApp(MyApp(initialThemeMode: initialThemeMode)); // Passar tema inicial
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode; // ADICIONADO: Receber tema inicial

  const MyApp({super.key, required this.initialThemeMode}); // Modificado construtor

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode; // Modificado para late

  @override
  void initState() {
    super.initState();
    // ADICIONADO: Definir tema inicial recebido do main
    _themeMode = widget.initialThemeMode;
  }

  // Modificado para salvar a preferência
  Future<void> changeTheme(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });
    // ADICIONADO: Salvar preferência
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
        background: const Color(0xFF121212),
        surface: const Color(0xFF1E1E1E),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: Colors.white,
        onSurface: Colors.white,
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
            return Colors.blue[300]?.withOpacity(0.5);
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
      themeMode: _themeMode, // Usa o estado atualizado
      home: const HomeScreen(),
    );
  }
}

