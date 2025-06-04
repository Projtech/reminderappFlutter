import 'dart:typed_data'; // <-- ADICIONAR IMPORT
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Importar permission_handler
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import 'package:flutter_timezone/flutter_timezone.dart'; // Importar flutter_timezone

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const String _channelId = 'reminder_channel_id';
  static const String _channelName = 'Lembretes Importantes';
  static const String _channelDescription = 'Canal para notificações de lembretes agendados.';

  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('NotificationService: Already initialized.');
      return;
    }
    try {
      debugPrint('NotificationService: Initializing...');
      tz.initializeTimeZones();
      try {
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
        debugPrint('NotificationService: Timezone initialized to $currentTimeZone');
      } catch (e) {
        debugPrint('❌ NotificationService: Failed to get/set local timezone: $e. Using default UTC.');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // --- CRIAÇÃO EXPLÍCITA DO CANAL ANDROID --- 
      await _createAndroidNotificationChannel();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Remover configurações específicas de iOS
      const settings = InitializationSettings(android: androidSettings);

      final bool? didInitialize = await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
      );

      debugPrint('NotificationService: Initialization result: $didInitialize');
      if (didInitialize ?? false) {
        _initialized = true;
        debugPrint('✅ NotificationService: Initialized successfully.');
        // Limpar notificações antigas ou inválidas na inicialização (opcional, mas pode ajudar)
        // await _cleanupOldNotifications(); 
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

  // --- MÉTODO PARA CRIAR O CANAL ANDROID (COM IMPORTANCE.HIGH E SOM PADRÃO) --- 
  static Future<void> _createAndroidNotificationChannel() async {
    // <-- AJUSTE: Manter Importance.high -->
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance, // Manter high
      playSound: true, // Manter som habilitado
      // <-- AJUSTE: Remover definição explícita de som para usar padrão -->
      // sound: RawResourceAndroidNotificationSound('notification'), // Remover se houver
      enableVibration: true,
      showBadge: true,
    );
    try {
       await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
       debugPrint('✅ NotificationService: Android channel "$_channelId" created/updated with Importance.high (using default sound).');
    } catch (e) {
       debugPrint('❌ NotificationService: Failed to create/update Android channel: $e');
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
      PermissionStatus status = await Permission.scheduleExactAlarm.status;
      debugPrint('NotificationService: Current Schedule Exact Alarm Permission Status: $status');
      // Consideramos granted ou limited como suficiente para tentar agendar.
      return status.isGranted || status.isLimited; 
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 NotificationService: Notification tapped (foreground/background/terminated): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
    // TODO: Implementar lógica de navegação ou ação baseada no payload
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
     debugPrint('♨️ NotificationService: Notification tapped (background isolate): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
     // Lógica limitada aqui, idealmente apenas marcação ou processamento leve.
  }

  // --- MÉTODO DE AGENDAMENTO ATUALIZADO (COM LOGS EXTRAS) --- 
  static Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate,
    String? category,
  }) async {
    debugPrint('NotificationService: Attempting to schedule notification ID $id for $scheduledDate...');
    if (!_initialized) {
      debugPrint('❌ NotificationService: Cannot schedule, service not initialized.');
      return false;
    }

    // 1. Verificar permissão básica de notificação
    bool hasNotificationPerm = await checkNotificationPermissionStatus();
    if (!hasNotificationPerm) {
        debugPrint('❌ NotificationService: Notification permission denied for ID $id. Cannot schedule.');
        return false;
    }

    // 2. Verificar permissão de alarme exato (Android 12+)
    bool canScheduleExact = await checkExactAlarmPermissionStatus();
    AndroidScheduleMode scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle; // Fallback para inexato se não permitido
    debugPrint('NotificationService: Scheduling ID $id with ${canScheduleExact ? "EXACT" : "INEXACT" } alarm mode.');

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      // Adicionar verificação mais robusta para datas passadas
      if (tzScheduledDate.isBefore(now.subtract(const Duration(seconds: 2)))) { 
        debugPrint('❌ NotificationService: Scheduled date $tzScheduledDate for ID $id is in the past (Now: $now). Skipping schedule.');
        return false;
      }
      if (title.trim().isEmpty) {
        debugPrint('❌ NotificationService: Title cannot be empty for ID $id. Skipping schedule.');
        return false;
      }

      // Usar o channelId definido na classe
      final androidDetails = AndroidNotificationDetails(
        _channelId, 
        _channelName, 
        channelDescription: _channelDescription,
        importance: Importance.high, // Manter high
        priority: Priority.high,
        ticker: 'ticker',
        playSound: true,
        sound: null, // Usar padrão
        enableVibration: true,
        visibility: NotificationVisibility.public,
        additionalFlags: Int32List.fromList([4]), // FLAG_SHOW_WHEN
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      // <-- LOG ADICIONAL -->
      debugPrint('NotificationService: AndroidDetails for ID $id:');
      debugPrint('  - channelId: ${androidDetails.channelId}');
      debugPrint('  - channelName: ${androidDetails.channelName}');
      debugPrint('  - importance: ${androidDetails.importance.toString()}');
      debugPrint('  - priority: ${androidDetails.priority.toString()}');
      debugPrint('  - playSound: ${androidDetails.playSound}');
      debugPrint('  - sound: ${androidDetails.sound == null ? "Default (null)" : androidDetails.sound.toString()}');
      debugPrint('  - enableVibration: ${androidDetails.enableVibration}');
      // <-- FIM LOG ADICIONAL -->

      debugPrint('NotificationService: Calling zonedSchedule for ID $id at $tzScheduledDate with title "$title" (Mode: $scheduleMode)');
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
      await debugInfo(); // Log do status após agendar
      return true;
    } catch (e, s) {
      debugPrint('❌ NotificationService: Error scheduling notification ID $id: $e');
      debugPrint('Stack trace: $s');
      if (e.toString().contains('permission') || e.toString().contains('exact_alarms_not_permitted')) {
          debugPrint('NotificationService: Scheduling failed likely due to permissions for ID $id.');
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

      debugPrint('🔍 --- DEBUG NOTIFICAÇÕES (Android Focus) ---');
      debugPrint('   - Inicializado: ✅');
      debugPrint('   - Permissão de Notificação: ${hasNotificationPermission ? "✅ Granted" : "❌ Denied/Unknown"}');
      debugPrint('   - Pode agendar alarmes exatos: ${canScheduleExact ? "✅ Granted/Limited" : "❌ Denied/Unknown"}');
      debugPrint('   - Agendadas (${scheduled.length}):');

      if (scheduled.isEmpty) {
        debugPrint('     - Nenhuma notificação agendada.');
      } else {
        for (final notification in scheduled) {
          String details = '';
          debugPrint('     - ID: ${notification.id} | Título: ${notification.title} | Payload: ${notification.payload}$details');
        }
      }
      debugPrint('🔍 --- FIM DEBUG NOTIFICAÇÕES ---');

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

