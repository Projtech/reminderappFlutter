import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Importar permission_handler
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      debugPrint('NotificationService: Initializing...');
      tz.initializeTimeZones();
      try {
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
        debugPrint('NotificationService: Timezone initialized to $currentTimeZone');
      } catch (e) {
        debugPrint('❌ NotificationService: Failed to get/set local timezone: $e. Using default.');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Remover configurações específicas de iOS, já que o foco é Android
      // const iosSettings = DarwinInitializationSettings(...);

      const settings = InitializationSettings(
        android: androidSettings,
        // iOS: iosSettings, // Remover iOS
      );

      final bool? didInitialize = await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
      );

      debugPrint('NotificationService: Initialization result: $didInitialize');
      if (didInitialize ?? false) {
        _initialized = true;
        debugPrint('✅ NotificationService: Initialized successfully.');
      } else {
        debugPrint('❌ NotificationService: Initialization failed.');
        _initialized = false;
      }
    } catch (e, s) {
      debugPrint('❌ NotificationService: Error initializing notifications: $e');
      debugPrint('Stack trace: $s');
      _initialized = false;
    }
  }

  // --- MÉTODO REVISADO PARA USAR PERMISSION_HANDLER --- 
  static Future<Map<Permission, PermissionStatus>> requestCorePermissions() async {
    if (!_initialized) {
       debugPrint('NotificationService: Cannot request permissions, service not initialized.');
       return {};
    }
    debugPrint('NotificationService: Requesting core permissions using permission_handler...');
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification, // Permissão básica de notificação (Android 13+)
      Permission.scheduleExactAlarm // Permissão para alarmes exatos (Android 12+)
    ].request();

    debugPrint('NotificationService: Permission statuses after request:');
    statuses.forEach((permission, status) {
      debugPrint('  ${permission.toString()}: ${status.toString()}');
    });

    return statuses;
  }

  // --- MÉTODO PARA VERIFICAR PERMISSÕES USANDO PERMISSION_HANDLER --- 
  static Future<bool> checkNotificationPermissionStatus() async {
      PermissionStatus status = await Permission.notification.status;
      debugPrint('NotificationService: Current Notification Permission Status: $status');
      return status.isGranted;
  }

  static Future<bool> checkExactAlarmPermissionStatus() async {
      // scheduleExactAlarm só existe a partir de uma certa versão do Android.
      // O permission_handler pode lidar com isso internamente ou retornar um status específico.
      // Em versões anteriores, pode não ser aplicável e podemos considerar como 'concedido' por padrão.
      // No entanto, para simplificar, vamos verificar o status diretamente.
      PermissionStatus status = await Permission.scheduleExactAlarm.status;
      debugPrint('NotificationService: Current Schedule Exact Alarm Permission Status: $status');
      // Consideramos granted ou limited como suficiente para tentar agendar.
      // 'limited' pode ocorrer em alguns cenários específicos.
      return status.isGranted || status.isLimited; 
  }

  // Remover _onDidReceiveLocalNotification pois é específico do iOS < 10
  // static void _onDidReceiveLocalNotification(...) { ... }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 NotificationService: Notification tapped (foreground/background/terminated): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
    // Lógica de navegação ou ação
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
     debugPrint('♨️ NotificationService: Notification tapped (background isolate): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
     // Lógica limitada aqui
  }

  // --- MÉTODO DE AGENDAMENTO ATUALIZADO --- 
  static Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate,
    String? category,
  }) async {
    debugPrint('NotificationService: Attempting to schedule notification ID $id...');
    if (!_initialized) {
      debugPrint('❌ NotificationService: Cannot schedule, service not initialized.');
      return false;
    }

    // 1. Verificar permissão básica de notificação
    bool hasNotificationPerm = await checkNotificationPermissionStatus();
    if (!hasNotificationPerm) {
        debugPrint('❌ NotificationService: Notification permission denied. Cannot schedule.');
        // Considerar solicitar permissão aqui ou informar o usuário
        // await requestCorePermissions(); // Poderia tentar solicitar novamente
        return false;
    }

    // 2. Verificar permissão de alarme exato (Android 12+)
    bool canScheduleExact = await checkExactAlarmPermissionStatus();
    AndroidScheduleMode scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle; // Fallback para inexato se não permitido
    debugPrint('NotificationService: Scheduling with ${canScheduleExact ? "EXACT" : "INEXACT" } alarm mode.');

    try {
      final now = tz.TZDateTime.now(tz.local);
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzScheduledDate.isBefore(now.subtract(const Duration(seconds: 5)))) { // Pequena margem
        debugPrint('⚠️ NotificationService: Scheduled date $tzScheduledDate is in the past. Now: $now');
        return false;
      }
      if (title.trim().isEmpty) {
        debugPrint('❌ NotificationService: Title cannot be empty.');
        return false;
      }

      const androidDetails = AndroidNotificationDetails(
        'reminder_channel_id', 
        'Lembretes Importantes', 
        channelDescription: 'Canal para notificações de lembretes agendados.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
        // enableLights: true, // Luzes podem não funcionar em todos aparelhos
        // ledColor: Colors.blue,
        // ledOnMs: 1000,
        // ledOffMs: 500,
        visibility: NotificationVisibility.public,
      );

      // Remover detalhes do iOS
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        // iOS: null, // Remover iOS
      );

      debugPrint('NotificationService: Scheduling notification ID $id for $tzScheduledDate with title "$title" (Mode: $scheduleMode)');
      await _notifications.zonedSchedule(
        id,
        title.trim(),
        description.trim().isEmpty ? title.trim() : description.trim(),
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_$id|${title.trim()}',
        matchDateTimeComponents: null,
      );

      debugPrint('✅ NotificationService: Notification ID $id scheduled successfully for $tzScheduledDate.');
      await debugInfo();
      return true;
    } catch (e, s) {
      debugPrint('❌ NotificationService: Error scheduling notification ID $id: $e');
      debugPrint('Stack trace: $s');
      if (e.toString().contains('permission') || e.toString().contains('exact_alarms_not_permitted')) {
          debugPrint('NotificationService: Scheduling failed likely due to permissions.');
          // Informar o usuário ou tentar abrir configurações
          // await openAppSettings(); // Usar permission_handler
      }
      return false;
    }
  }

  // Manter funções de cancelamento e listagem
  static Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    debugPrint('NotificationService: Canceling notification ID $id...');
    try {
      await _notifications.cancel(id);
      debugPrint('🗑️ NotificationService: Notification ID $id canceled.');
      await debugInfo();
    } catch (e) {
      debugPrint('❌ NotificationService: Error canceling notification ID $id: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    debugPrint('NotificationService: Canceling ALL notifications...');
    try {
      await _notifications.cancelAll();
      debugPrint('🗑️ NotificationService: All notifications canceled.');
      await debugInfo();
    } catch (e) {
      debugPrint('❌ NotificationService: Error canceling all notifications: $e');
    }
  }

  static Future<List<PendingNotificationRequest>> getScheduledNotifications() async {
    if (!_initialized) return [];
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ NotificationService: Error listing scheduled notifications: $e');
      return [];
    }
  }

  // --- MÉTODO DE DEBUG ATUALIZADO --- 
  static Future<void> debugInfo() async {
    if (!_initialized) {
       debugPrint('🔍 DEBUG NOTIFICAÇÕES: Service not initialized.');
       return;
    }
    try {
      final scheduled = await getScheduledNotifications();
      final hasNotificationPermission = await checkNotificationPermissionStatus();
      final canScheduleExact = await checkExactAlarmPermissionStatus();

      debugPrint('🔍 DEBUG NOTIFICAÇÕES (Android Focus):');
      debugPrint('   - Inicializado: ✅');
      debugPrint('   - Permissão de Notificação: ${hasNotificationPermission ? "✅" : "❌"}');
      debugPrint('   - Pode agendar alarmes exatos: ${canScheduleExact ? "✅" : "❌"}');
      debugPrint('   - Agendadas (${scheduled.length}):');

      if (scheduled.isEmpty) {
        debugPrint('     - Nenhuma notificação agendada.');
      } else {
        for (final notification in scheduled) {
          debugPrint('     - ID: ${notification.id} | Título: ${notification.title} | Payload: ${notification.payload}');
        }
      }
    } catch (e) {
      debugPrint('❌ NotificationService: Error getting debug info: $e');
    }
  }

  // --- MÉTODO PARA ABRIR CONFIGURAÇÕES USANDO PERMISSION_HANDLER --- 
  static Future<void> openSettingsAndRequestPermissions() async {
    debugPrint('NotificationService: Checking permissions and potentially opening settings...');
    Map<Permission, PermissionStatus> statuses = await requestCorePermissions();
    
    bool allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);

    if (!allGranted) {
        debugPrint('NotificationService: Not all permissions granted. Opening app settings...');
        bool didOpen = await openAppSettings(); // Função do permission_handler
        if (!didOpen) {
            debugPrint('NotificationService: Could not open app settings.');
            // Informar o usuário que ele precisa habilitar manualmente
        }
    } else {
        debugPrint('NotificationService: All required permissions seem to be granted.');
    }
  }

  // Manter função de teste
  static Future<void> scheduleTestNotification(int seconds) async {
    debugPrint('NotificationService: Scheduling TEST notification in $seconds seconds...');
    final now = DateTime.now();
    await scheduleNotification(
      id: 9999, 
      title: '🔔 Teste de Notificação 🔔',
      description: 'Esta é uma notificação de teste agendada para ${seconds}s após ${DateFormat.Hms().format(now)}.',
      scheduledDate: now.add(Duration(seconds: seconds)),
    );
  }
}

// Classe auxiliar para obter timezone (mantida como estava)
class FlutterTimezone {
  static const MethodChannel _channel =
      MethodChannel('flutter_timezone');

  static Future<String> getLocalTimezone() async {
    try {
       final String timezone = await _channel.invokeMethod('getLocalTimezone');
       return timezone;
    } catch (e) {
       debugPrint('FlutterTimezone: Failed to get timezone: $e. Returning UTC.');
       return 'UTC';
    }
  }
}

