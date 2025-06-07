import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const String _channelId = 'heads_up_urgent_channel';
  static const String _channelName = 'Heads-Up Urgentes';
  static const String _channelDescription = 'Notificações que aparecem na tela com som.';

  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      tz.initializeTimeZones();
      try {
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
      } catch (e) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      await _createAndroidNotificationChannel();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);

      final bool? didInitialize = await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
      );

      if (didInitialize ?? false) {
        _initialized = true;
      } else {
        _initialized = false;
      }
    } catch (e) {
      _initialized = false;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _createAndroidNotificationChannel() async {
    try {
      await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.deleteNotificationChannel('reminder_channel_id');
    } catch (e) {
      // Ignore deletion errors
    }

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    try {
       await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
    } catch (e) {
      // Ignore creation errors
    }
  }

  @pragma('vm:entry-point')
  static Future<Map<Permission, PermissionStatus>> requestCorePermissions() async {
    if (!_initialized) {
       return {};
    }
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.scheduleExactAlarm
    ].request();

    statuses.forEach((permission, status) {
    });

    return statuses;
  }

  @pragma('vm:entry-point')
  static Future<bool> checkNotificationPermissionStatus() async {
      PermissionStatus status = await Permission.notification.status;
      return status.isGranted;
  }

  @pragma('vm:entry-point')
  static Future<bool> checkExactAlarmPermissionStatus() async {
      PermissionStatus status = await Permission.scheduleExactAlarm.status;
      return status.isGranted || status.isLimited; 
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
  }

  @pragma('vm:entry-point')
  static Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate,
    String? category,
  }) async {
    if (!_initialized) {
      return false;
    }

    bool hasNotificationPerm = await checkNotificationPermissionStatus();
    if (!hasNotificationPerm) {
        return false;
    }

    bool canScheduleExact = await checkExactAlarmPermissionStatus();
    AndroidScheduleMode scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzScheduledDate.isBefore(now.subtract(const Duration(seconds: 2)))) { 
        return false;
      }
      if (title.trim().isEmpty) {
        return false;
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId, 
        _channelName, 
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        
        playSound: true,
        sound: null,
        enableVibration: true,
        
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        autoCancel: true,
        ongoing: false,
        when: DateTime.now().millisecondsSinceEpoch,
        showWhen: true,
        ticker: title.trim(),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);


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

      await debugInfo();
      return true;
    } catch (e) {
      if (e.toString().contains('permission') || e.toString().contains('exact_alarms_not_permitted')) {
      }
      return false;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _notifications.cancel(id);
      await debugInfo();
    } catch (e) {
      // Ignore cancellation errors
    }
  }

  @pragma('vm:entry-point')
  static Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    try {
      await _notifications.cancelAll();
      await debugInfo();
    } catch (e) {
      // Ignore cancellation errors
    }
  }

  @pragma('vm:entry-point')
  static Future<List<PendingNotificationRequest>> getScheduledNotifications() async {
    if (!_initialized) return [];
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      return [];
    }
  }

  @pragma('vm:entry-point')
  static Future<void> debugInfo() async {
    if (!_initialized) {
       return;
    }
    try {
      final scheduled = await getScheduledNotifications();
      await checkNotificationPermissionStatus();
      await checkExactAlarmPermissionStatus();

      if (scheduled.isEmpty) {
      } else {
        for (final _ in scheduled) {
          // Process notification if needed
        }
      }

    } catch (e) {
      // Ignore debug errors
    }
  }

  @pragma('vm:entry-point')
  static Future<void> openSettingsAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await requestCorePermissions();
    
    bool allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);

    if (!allGranted) {
        bool didOpen = await openAppSettings();
        if (!didOpen) {
        }
    } else {
    }
  }

  @pragma('vm:entry-point')
  static Future<void> scheduleTestNotification(int seconds) async {
    final now = DateTime.now();
    await scheduleNotification(
      id: 9999, 
      title: '🚨 HEADS-UP CORRIGIDO 🚨',
      description: 'Agora sem erro de LED - deve aparecer!',
      scheduledDate: now.add(Duration(seconds: seconds)),
    );
  }

  // ✅ NOVOS MÉTODOS PARA TESTE E VERIFICAÇÃO DE BATERIA

  @pragma('vm:entry-point')
  static Future<void> checkMotorolaSettings() async {
  }

  @pragma('vm:entry-point')
  static Future<void> requestBatteryOptimizationDisable() async {
    
    try {
      PermissionStatus status = await Permission.ignoreBatteryOptimizations.status;
      
      if (!status.isGranted) {
        PermissionStatus newStatus = await Permission.ignoreBatteryOptimizations.request();
        
        if (!newStatus.isGranted) {
          await openAppSettings();
        } else {
        }
      } else {
      }
    } catch (e) {
      await openAppSettings();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> testeGradualNotificacoes() async {
    
    // 1. Verificar configurações primeiro
    await checkMotorolaSettings();
    
    
    await scheduleTestNotification(10);
    
  }

  @pragma('vm:entry-point')
  static Future<void> testeComAppFechado() async {
    
    
    await scheduleTestNotification(15);
    
  }

  @pragma('vm:entry-point')
  static Future<void> testeComTelaLigada() async {
    
    
    await scheduleTestNotification(8);
    
  }
}