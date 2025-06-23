import 'dart:async';
import 'update_service.dart';
import 'notification_service.dart';

class TimerService {
  static Timer? _timer;
  static bool _isRunning = false;

  // Inicializar verificação a cada 12 horas
  static Future<void> initialize() async {
    await scheduleUpdateChecks();
  }

  // Agendar verificações periódicas
  static Future<void> scheduleUpdateChecks() async {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Verificação a cada 12 horas (43200 segundos)
    _timer = Timer.periodic(const Duration(hours: 12), (timer) async {
      await _checkForUpdates();
    });
    
    // Primeira verificação após 1 minuto
    Timer(const Duration(minutes: 1), () async {
      await _checkForUpdates();
    });
  }

  // Parar verificações
  static void cancelUpdateChecks() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  // Verificar atualizações
  static Future<void> _checkForUpdates() async {
    try {
      final shouldCheck = await UpdateService.shouldCheckForUpdates();
      
      if (shouldCheck) {
        final updateInfo = await UpdateService.getUpdateInfo();
        
        if (updateInfo != null) {
          await NotificationService.showUpdateNotification(updateInfo);
        }
      }
    } catch (e) {
      // Falha silenciosa em background
    }
  }

  // Verificação manual
  static Future<void> checkNow() async {
    await _checkForUpdates();
  }
}