import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/notification_service.dart';
import 'services/timer_service.dart';
import 'services/consent_service.dart';
import 'services/auth_service.dart';
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
      home: const AuthWrapper(), // ✅ MUDANÇA: Trocado de HomeScreen para AuthWrapper
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

// ✅ NOVA CLASSE: AuthWrapper que verifica autenticação ANTES de mostrar conteúdo
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isCheckingAuth = true;
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialAuth();
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
      _checkAuthOnResume();
    }
  }

  Future<void> _checkInitialAuth() async {
    try {
      // Verificar se segurança está habilitada
      final isSecurityEnabled = await AuthService.isSecurityEnabled();
      
      if (!isSecurityEnabled) {
        setState(() {
          _isCheckingAuth = false;
        });
        return;
      }
      
      // Verificar se precisa autenticar
      final needsAuth = await AuthService.needsAuthentication();
      
      if (needsAuth && mounted) {
        // Mostrar tela de autenticação
        final authenticated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthScreen(),
            settings: const RouteSettings(name: '/auth'),
          ),
        );
        
        // Se não autenticou, fechar o app
        if (authenticated != true && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          SystemNavigator.pop();
          return;
        }
      }
      
      // Autenticado ou não precisa, mostrar home
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      // Em caso de erro, não exigir autenticação para não travar o app
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _checkAuthOnResume() async {
    try {
      final isSecurityEnabled = await AuthService.isSecurityEnabled();
      if (!isSecurityEnabled) return;
      
      final needsAuth = await AuthService.needsAuthentication();
      if (needsAuth && mounted) {
        final authenticated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthScreen(),
            settings: const RouteSettings(name: '/auth'),
          ),
        );
        
        if (authenticated != true && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      // Error handled silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Enquanto verifica autenticação, mostrar loading seguro
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Verificando segurança...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Se passou pela verificação, mostrar HomeScreen
    return const HomeScreen();
  }
}