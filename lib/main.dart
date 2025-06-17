import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/report_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  
  // ✅ NOVO: Inicializar Supabase
  await ReportService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final String? themeModeString = prefs.getString('theme_mode');
  ThemeMode initialThemeMode = (themeModeString == 'dark') ? ThemeMode.dark : ThemeMode.light;

  runApp(MyApp(initialThemeMode: initialThemeMode));
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, required this.initialThemeMode});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // ✅ CORREÇÃO 1: Tornar classe pública e método público
  static MyAppState? of(BuildContext context) => context.findAncestorStateOfType<MyAppState>();

  @override
  State<MyApp> createState() => MyAppState(); // ✅ Retornar classe pública
}

// ✅ CORREÇÃO 1: Remover underscore para tornar público
class MyAppState extends State<MyApp> {
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
        surface: const Color(0xFF1E1E1E),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
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
            // ✅ CORREÇÃO 2: Usar withValues em vez de withAlpha
            return Colors.blue[300]?.withValues(alpha: 0.5); // 128/255 ≈ 0.5
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
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}