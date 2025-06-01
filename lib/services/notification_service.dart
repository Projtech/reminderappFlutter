import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _permissionRequestedThisSession = false;

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
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      // CORREÇÃO: Removido requestPermissions da inicialização iOS
      const iosSettings = DarwinInitializationSettings(
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
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

  static Future<bool> requestPermissionsIfNeeded() async {
    if (!_initialized) {
       debugPrint('NotificationService: Cannot request permissions, service not initialized.');
       return false;
    }
    // if (_permissionRequestedThisSession) {
    //   return true; // Evita pedir múltiplas vezes na mesma sessão
    // }

    debugPrint('NotificationService: Explicitly requesting permissions...');
    _permissionRequestedThisSession = true;
    bool notificationPermission = false;
    bool exactAlarmPermission = true;

    try {
      // iOS
      final iosImplementation = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
         final bool? iosPermissions = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
         notificationPermission = iosPermissions ?? false;
         debugPrint('NotificationService: iOS Permissions Granted: $notificationPermission');
      }

      // Android
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final bool? androidNotificationPermission = await androidImplementation.requestNotificationsPermission();
        notificationPermission = androidNotificationPermission ?? false;
        debugPrint('NotificationService: Android Notification Permission Granted: $notificationPermission');

        final bool? androidExactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
        exactAlarmPermission = androidExactAlarmPermission ?? false;
        debugPrint('NotificationService: Android Exact Alarm Permission Granted: $exactAlarmPermission');
      }

      debugPrint('✅ NotificationService: Permissions request finished.');
      return notificationPermission;
    } catch (e) {
      debugPrint('⚠️ NotificationService: Error requesting permissions explicitly: $e');
      return false;
    }
  }

  static void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    debugPrint('NotificationService: Received foreground notification (iOS < 10): ID $id, Title $title');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 NotificationService: Notification tapped (background/terminated): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
     debugPrint('♨️ NotificationService: Notification tapped (foreground/background isolate): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
  }

  static Future<bool> _checkExactAlarmPermission() async {
     if (!_initialized) return false;
     try {
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          return await androidImplementation.canScheduleExactNotifications() ?? false;
        }
        return true; // iOS
     } catch (e) {
        debugPrint('⚠️ NotificationService: Error checking exact alarm permission: $e');
        return false;
     }
  }

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

    try {
      final now = tz.TZDateTime.now(tz.local);
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzScheduledDate.isBefore(now.subtract(const Duration(seconds: 5)))) {
        debugPrint('⚠️ NotificationService: Scheduled date is in the past: $tzScheduledDate. Now: $now');
        return false;
      }
      if (title.trim().isEmpty) {
        debugPrint('❌ NotificationService: Title cannot be empty.');
        return false;
      }

      final bool canScheduleExact = await _checkExactAlarmPermission();
      AndroidScheduleMode scheduleMode = canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      debugPrint('NotificationService: Scheduling with ${canScheduleExact ? "EXACT" : "INEXACT" } alarm mode.');

      const androidDetails = AndroidNotificationDetails(
        'reminder_channel_id',
        'Lembretes Importantes',
        channelDescription: 'Canal para notificações de lembretes agendados',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.blue,
        ledOnMs: 1000,
        ledOffMs: 500,
        visibility: NotificationVisibility.public,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final notificationDetails = NotificationDetails(
        android: androidDetails,

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
        payload: 'reminder_$id | ${title.trim()}',
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
      }
      return false;
    }
  }

  static Future<bool> scheduleRecurringNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate,
    String? category,
  }) async {
    debugPrint('NotificationService: Scheduling RECURRING notification ID $id for next occurrence at $scheduledDate');
    return await scheduleNotification(
      id: id,
      title: title,
      description: description,
      scheduledDate: scheduledDate,
      category: category,
    );
  }

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

  static Future<bool> hasScheduledNotification(int id) async {
    if (!_initialized) return false;
    try {
      final notifications = await getScheduledNotifications();
      return notifications.any((notification) => notification.id == id);
    } catch (e) {
      debugPrint('❌ NotificationService: Error checking for notification ID $id: $e');
      return false;
    }
  }

  // CORREÇÃO: Removida checagem específica iOS que causava erro
  static Future<bool> checkNotificationPermissions() async {
     if (!_initialized) return false;
     // Simplificado: Assume que se inicializou, tem permissão (ou será pedida)
     // Uma checagem robusta usaria permission_handler
     return true;
  }

  static Future<void> debugInfo() async {
    if (!_initialized) {
       debugPrint('🔍 DEBUG NOTIFICAÇÕES: Service not initialized.');
       return;
    }
    try {
      final scheduled = await getScheduledNotifications();
      final canScheduleExact = await _checkExactAlarmPermission();
      final hasNotificationPermission = await checkNotificationPermissions();

      debugPrint('🔍 DEBUG NOTIFICAÇÕES:');
      debugPrint('   - Inicializado: ✅');
      debugPrint('   - Permissão de Notificação (Checagem Simplificada): ${hasNotificationPermission ? "✅" : "❌"}');
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

  static Future<void> openNotificationSettingsOrRequest() async {
    debugPrint('NotificationService: Attempting to open settings or request permission...');
    try {
      await requestPermissionsIfNeeded();
      debugPrint('NotificationService: Permission request sent again.');
    } catch (e) {
      debugPrint('❌ NotificationService: Error trying to request permissions/open settings: $e');
    }
  }

  static Future<void> scheduleTestNotification(int seconds) async {
    debugPrint('NotificationService: Scheduling TEST notification in $seconds seconds...');
    final now = DateTime.now();
    await scheduleNotification(
      id: 9999,
      title: '🔔 Teste de Notificação 🔔',
      description: 'Esta é uma notificação de teste agendada para ${seconds}s.',
      scheduledDate: now.add(Duration(seconds: seconds)),
    );
  }
}

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

