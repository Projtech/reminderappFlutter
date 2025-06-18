// lib/services/report_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_info.dart';
import 'consent_service.dart';
import '../services/privacy_settings_service.dart';

class ReportService {
  static const String _supabaseUrl = 'https://ptivwmuxlmmqxjhwxwgr.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0aXZ3bXV4bG1tcXhqaHd4d2dyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxMTgxMzQsImV4cCI6MjA2NTY5NDEzNH0.QpBxX5tWVeNPbtlV-xZKwRa3VbzsaGzNkD8MrYvuyfA';

  static bool _initialized = false;

  // Inicializar Supabase (chamado no main.dart)
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      _initialized = true;
    } catch (e) {
      if (kDebugMode) print('Erro ao inicializar Supabase: $e');
    }
  }

  // Coletar dados técnicos do dispositivo
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'device_model': '${androidInfo.manufacturer} ${androidInfo.model}',
          'android_version': 'Android ${androidInfo.version.release}',
          'app_version': '${packageInfo.version} (${packageInfo.buildNumber})',
          'device_type': 'Android',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'device_model': '${iosInfo.name} ${iosInfo.model}',
          'android_version': 'iOS ${iosInfo.systemVersion}',
          'app_version': '${packageInfo.version} (${packageInfo.buildNumber})',
          'device_type': 'iOS',
        };
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao coletar info do dispositivo: $e');
    }

    return {
      'device_model': 'Desconhecido',
      'android_version': 'Desconhecido',
      'app_version': AppInfo.version,
      'device_type': 'Desconhecido',
    };
  }

  // Enviar report para Supabase
  static Future<bool> sendReport({
    required String message,
    required String type, // 'bug' ou 'suggestion'
    String? userName,
    String? userEmail,
    bool includeTechnicalData = false,
  }) async {
    try {
      // Verificar consentimento
      final consentService = ConsentService();
      final hasConsent = await consentService.isDataCollectionEnabled();

      if (!hasConsent && includeTechnicalData) {
        if (kDebugMode) {
          print('Usuário não deu consentimento para coleta de dados');
        }
        return false;
      }

      if (!_initialized) {
        await initialize();
      }

      final supabase = Supabase.instance.client;

      // Preparar dados para envio
      Map<String, dynamic> reportData = {
        'message': message,
        'report_type': type,
        'user_name': userName,
        'user_email': userEmail,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Adicionar dados técnicos se permitido
      if (hasConsent && includeTechnicalData) {
        final deviceInfo = await _getDeviceInfo();
        reportData.addAll(deviceInfo);
      }

      // Enviar para Supabase
      final response = await supabase
          .from('reports') // Nome da tabela que vamos criar
          .insert(reportData);
      final privacyService = PrivacySettingsService();
      await privacyService.incrementReportsCount();

      if (kDebugMode) print('Report enviado com sucesso: $response');
      return true;
    } catch (e) {
      if (kDebugMode) print('Erro ao enviar report: $e');
      return false;
    }
  }
}
