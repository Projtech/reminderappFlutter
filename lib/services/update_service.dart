import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_info.dart';

class UpdateService {
  static const String _apiUrl = 'https://seuslembretes.vercel.app/api/version';
  static const String _lastCheckKey = 'last_update_check';
  static const String _cachedVersionKey = 'cached_version_info';

  // Buscar informações da versão atual da API
  static Future<Map<String, dynamic>?> fetchLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _cacheVersionInfo(data);
        return data;
      }
    } catch (e) {
      // Se falhar, tenta buscar do cache
      return await _getCachedVersionInfo();
    }
    return null;
  }

  // Comparar versão atual com a versão da API
  static Future<bool> hasUpdate() async {
    final latestVersion = await fetchLatestVersion();
    if (latestVersion == null) return false;
    
    final apiVersion = latestVersion['version'] as String?;
    if (apiVersion == null) return false;
    
    return _compareVersions(AppInfo.version, apiVersion);
  }

  // Obter informações de atualização
  static Future<Map<String, dynamic>?> getUpdateInfo() async {
    final hasNewUpdate = await hasUpdate();
    if (!hasNewUpdate) return null;
    
    return await fetchLatestVersion();
  }

  // Comparar duas versões (retorna true se apiVersion é maior)
// Comparar duas versões (retorna true se apiVersion é maior)
  static bool _compareVersions(String currentVersion, String apiVersion) {
    try {
      // Remove qualquer coisa após o '+' (build number)
      final cleanCurrent = currentVersion.split('+')[0];
      final cleanApi = apiVersion.split('+')[0];
      
      final current = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final api = cleanApi.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      final maxLength = current.length > api.length ? current.length : api.length;
      
      for (int i = 0; i < maxLength; i++) {
        final currentPart = i < current.length ? current[i] : 0;
        final apiPart = i < api.length ? api[i] : 0;
        
        if (apiPart > currentPart) return true;
        if (apiPart < currentPart) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Salvar informações no cache
  static Future<void> _cacheVersionInfo(Map<String, dynamic> versionInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedVersionKey, jsonEncode(versionInfo));
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Obter informações do cache
  static Future<Map<String, dynamic>?> _getCachedVersionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedVersionKey);
    if (cached != null) {
      return jsonDecode(cached);
    }
    return null;
  }

  // Verificar se já passou 12 horas desde a última verificação
  static Future<bool> shouldCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const twelveHours = 12 * 60 * 60 * 1000; // 12 horas em milissegundos
    
    return (now - lastCheck) >= twelveHours;
  }
}