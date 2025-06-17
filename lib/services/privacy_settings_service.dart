// lib/services/privacy_settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySettingsService {
  static const String _keyDataCollection = 'data_collection_consent';
  static const String _keyPixSuggestions = 'privacy_pix_suggestions';
  static const String _keyReportsCount = 'privacy_reports_count';
  static const String _keyLastDataClear = 'privacy_last_data_clear';
  static const String _keyFirstCollection = 'privacy_first_collection';
  static const String _keyLastCollection = 'privacy_last_collection';

  // Carregar todas as configurações
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final lastDataClearString = prefs.getString(_keyLastDataClear);
    DateTime? lastDataClear;
    if (lastDataClearString != null) {
      lastDataClear = DateTime.tryParse(lastDataClearString);
    }
    
    return {
      'dataCollection': prefs.getBool(_keyDataCollection) ?? false,
      'pixSuggestions': prefs.getBool(_keyPixSuggestions) ?? true,
      'reportsCount': prefs.getInt(_keyReportsCount) ?? 0,
      'lastDataClear': lastDataClear,
    };
  }

  // Atualizar configuração de coleta de dados
  Future<void> updateDataCollection(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDataCollection, enabled);
    
    // Se ativando pela primeira vez, marcar data
    if (enabled && !prefs.containsKey(_keyFirstCollection)) {
      await prefs.setString(_keyFirstCollection, DateTime.now().toIso8601String());
    }
  }

  // Atualizar configuração de sugestões PIX
  Future<void> updatePixSuggestions(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPixSuggestions, enabled);
  }

  // Incrementar contador de reports
  Future<void> incrementReportsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyReportsCount) ?? 0;
    await prefs.setInt(_keyReportsCount, current + 1);
    await prefs.setString(_keyLastCollection, DateTime.now().toIso8601String());
  }

  // Limpar todos os dados
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReportsCount, 0);
    await prefs.setString(_keyLastDataClear, DateTime.now().toIso8601String());
    await prefs.remove(_keyFirstCollection);
    await prefs.remove(_keyLastCollection);
  }

  // Obter resumo dos dados coletados
  Future<Map<String, dynamic>> getCollectedDataSummary() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'reportsCount': prefs.getInt(_keyReportsCount) ?? 0,
      'firstCollection': prefs.getString(_keyFirstCollection),
      'lastCollection': prefs.getString(_keyLastCollection),
    };
  }

  // Verificar se coleta está ativa
  Future<bool> isDataCollectionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDataCollection) ?? false;
  }

  // Verificar se sugestões PIX estão ativas
  Future<bool> arePixSuggestionsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPixSuggestions) ?? true;
  }
}