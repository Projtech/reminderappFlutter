import 'package:shared_preferences/shared_preferences.dart';

class ConsentService {
  static const String _consentKey = 'data_collection_consent';
  static const String _consentVersionKey = 'consent_version';
  static const String _currentConsentVersion = '1.0';
  
  // Singleton
  static final ConsentService _instance = ConsentService._internal();
  factory ConsentService() => _instance;
  ConsentService._internal();

  SharedPreferences? _prefs;

  // Inicializar SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Garantir que está inicializado
  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // Verificar se já mostrou o consentimento
  Future<bool> hasShownConsent() async {
    final preferences = await prefs;
    final hasConsent = preferences.getBool(_consentKey) != null;
    final version = preferences.getString(_consentVersionKey);
    
    // Se não tem consentimento OU versão diferente, precisa mostrar
    return hasConsent && version == _currentConsentVersion;
  }

  // Verificar se usuário aceitou coleta de dados
  Future<bool> isDataCollectionEnabled() async {
    final preferences = await prefs;
    return preferences.getBool(_consentKey) ?? false;
  }

  // Salvar consentimento do usuário
  Future<bool> saveConsent(bool accepted) async {
    try {
      final preferences = await prefs;
      await preferences.setBool(_consentKey, accepted);
      await preferences.setString(_consentVersionKey, _currentConsentVersion);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Resetar consentimento (para testes ou mudança de versão)
  Future<bool> resetConsent() async {
    try {
      final preferences = await prefs;
      await preferences.remove(_consentKey);
      await preferences.remove(_consentVersionKey);
      return true;
    } catch (e) {
      return false;
    }
  }
}