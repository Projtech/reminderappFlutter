// lib/services/pix_suggestion_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class PixSuggestionService {
  // Chaves para SharedPreferences
  static const String _lastSuggestionKey = 'last_pix_suggestion';
  static const String _suggestionCountKey = 'pix_suggestion_count';
  static const String _userDeclinedKey = 'user_declined_pix';
  static const String _userSupportedKey = 'user_supported_pix';
  
  // Configurações do sistema
  static const int _cooldownHours = 6;
  static const int _maxSuggestionsPerWeek = 3; // Máximo 3x por semana
  static const int _minActionsBeforeSuggestion = 1; // ← CORRIGIDO: Pelo menos 1 ação
  
  // Singleton
  static final PixSuggestionService _instance = PixSuggestionService._internal();
  factory PixSuggestionService() => _instance;
  PixSuggestionService._internal();

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

  // ✅ FUNÇÃO PRINCIPAL: Verificar se deve sugerir PIX
// ✅ ADICIONAR no pix_suggestion_service.dart na função shouldSuggestPix():

Future<bool> shouldSuggestPix() async {
  try {
    final preferences = await prefs;
    
    // 1. Verificar se usuário já declinou muitas vezes
    final userDeclined = preferences.getBool(_userDeclinedKey) ?? false;
    if (userDeclined) return false;
    
    // 2. Verificar se usuário já apoiou
    final userSupported = preferences.getBool(_userSupportedKey) ?? false;
    
    // 3. Verificar cooldown (6h desde última sugestão)
    final lastSuggestion = preferences.getInt(_lastSuggestionKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastSuggestion = (now - lastSuggestion) / (1000 * 60 * 60);
    
    if (hoursSinceLastSuggestion < _cooldownHours) {
      return false;
    }
    
    // 4. Verificar limite semanal
    final suggestionCount = await _getWeeklySuggestionCount();
    if (suggestionCount >= _maxSuggestionsPerWeek) return false;
    
    // 5. Verificar se usuário fez ações suficientes
    final actionCount = await _getActionCount();
    if (actionCount < _minActionsBeforeSuggestion) return false;
    
    // 6. Chance aleatória
    final random = Random();
    final chance = userSupported ? 0.5 : 0.85;
    final randomValue = random.nextDouble();
    
    return randomValue < chance;
    
  } catch (e) {
    return false;
  }
}

  // ✅ Registrar momento positivo (criar/completar lembrete)
  Future<void> registerPositiveAction() async {
    try {
      final preferences = await prefs;
      final currentCount = preferences.getInt('positive_actions_count') ?? 0;
      await preferences.setInt('positive_actions_count', currentCount + 1);
    } catch (e) {
      // Falha silenciosa
    }
  }

  // ✅ Registrar que sugestão foi mostrada
  Future<void> registerSuggestionShown() async {
    try {
      final preferences = await prefs;
      final now = DateTime.now().millisecondsSinceEpoch;
      await preferences.setInt(_lastSuggestionKey, now);
      
      // Incrementar contador semanal
      await _incrementWeeklySuggestionCount();
    } catch (e) {
      // Falha silenciosa
    }
  }

  // ✅ Usuario apoiou com PIX
  Future<void> registerUserSupported() async {
    try {
      final preferences = await prefs;
      await preferences.setBool(_userSupportedKey, true);
      // Reset no contador de recusas
      await preferences.setBool(_userDeclinedKey, false);
    } catch (e) {
      // Falha silenciosa
    }
  }

  // ✅ Usuario recusou PIX
  Future<void> registerUserDeclined() async {
    try {
      final preferences = await prefs;
      final currentDeclines = preferences.getInt('decline_count') ?? 0;
      
      // Se recusou 3+ vezes, marcar como "não incomodar"
      if (currentDeclines >= 2) {
        await preferences.setBool(_userDeclinedKey, true);
      } else {
        await preferences.setInt('decline_count', currentDeclines + 1);
      }
    } catch (e) {
      // Falha silenciosa
    }
  }

  // ✅ Obter contagem de ações positivas
  Future<int> _getActionCount() async {
    final preferences = await prefs;
    return preferences.getInt('positive_actions_count') ?? 0;
  }

  // ✅ Contar sugestões desta semana
  Future<int> _getWeeklySuggestionCount() async {
    final preferences = await prefs;
    final lastResetWeek = preferences.getInt('last_reset_week') ?? 0;
    final currentWeek = _getCurrentWeekNumber();
    
    // Se mudou de semana, resetar contador
    if (currentWeek != lastResetWeek) {
      await preferences.setInt('weekly_suggestion_count', 0);
      await preferences.setInt('last_reset_week', currentWeek);
      return 0;
    }
    
    return preferences.getInt('weekly_suggestion_count') ?? 0;
  }

  // ✅ Incrementar contador semanal
  Future<void> _incrementWeeklySuggestionCount() async {
    final currentCount = await _getWeeklySuggestionCount();
    final preferences = await prefs;
    await preferences.setInt('weekly_suggestion_count', currentCount + 1);
  }

  // ✅ Calcular número da semana do ano
  int _getCurrentWeekNumber() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final days = now.difference(startOfYear).inDays;
    return (days / 7).floor();
  }

  // ✅ Para debug/testes - resetar tudo
  Future<void> resetForTesting() async {
    try {
      final preferences = await prefs;
      await preferences.remove(_lastSuggestionKey);
      await preferences.remove(_suggestionCountKey);
      await preferences.remove(_userDeclinedKey);
      await preferences.remove(_userSupportedKey);
      await preferences.remove('positive_actions_count');
      await preferences.remove('decline_count');
      await preferences.remove('weekly_suggestion_count');
      await preferences.remove('last_reset_week');
    } catch (e) {
      // Falha silenciosa
    }
  }
}