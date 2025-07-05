import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/timer_service.dart';
import 'services/consent_service.dart';
import 'widgets/whats_new_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  await NotificationService.initialize();

await TimerService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final String? themeModeString = prefs.getString('theme_mode');
  ThemeMode initialThemeMode =
      (themeModeString == 'dark') ? ThemeMode.dark : ThemeMode.light;

  runApp(MyApp(initialThemeMode: initialThemeMode));
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, required this.initialThemeMode});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ✅ CORREÇÃO 1: Tornar classe pública e método público
  static MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>();

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
    // Verificar se deve mostrar "O que há de novo" após o build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWhatsNewModal();
    });
  }

  Future<void> changeTheme(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme_mode', themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  // Nova função para verificar e mostrar modal "O que há de novo"
  Future<void> _checkWhatsNewModal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final consentService = ConsentService();
      
      // Verificar se usuário é antigo (já passou pelo LGPD)
      final hasShownConsent = await consentService.hasShownConsent();
      
      // Verificar se deve mostrar modal de novidades
      final shouldShowWhatsNew = prefs.getBool('show_whats_new_on_open') ?? false;
      
      // Só mostrar para usuários antigos que atualizaram
      if (hasShownConsent && shouldShowWhatsNew) {
        // Aguardar um pouco para garantir que a UI está pronta
        await Future.delayed(const Duration(milliseconds: 1000));
        
        final context = MyApp.navigatorKey.currentContext;
        if (context != null && mounted) {
          // ignore: use_build_context_synchronously
          await WhatsNewDialog.show(context);
          
          // Limpar a flag para não mostrar novamente
          await prefs.setBool('show_whats_new_on_open', false);
        }
      }
    } catch (e) {
      // Falha silenciosa
    }
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
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
      title: 'Seus Lembretes',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: const HomeScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}