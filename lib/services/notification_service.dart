import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart'; // Adicionado import para DateFormat

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  // static bool _permissionRequestedThisSession = false; // REMOVIDO - unused_field

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      debugPrint('NotificationService: Initializing...');
      tz.initializeTimeZones();
      try {
        // Usando a classe FlutterTimezone definida abaixo
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
        debugPrint('NotificationService: Timezone initialized to $currentTimeZone');
      } catch (e) {
        debugPrint('❌ NotificationService: Failed to get/set local timezone: $e. Using default.');
        // Considerar definir um timezone padrão seguro, como UTC
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
        // requestAlertPermission, requestBadgePermission, requestSoundPermission são gerenciados por requestPermissionsIfNeeded
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

    debugPrint('NotificationService: Explicitly requesting permissions...');
    // _permissionRequestedThisSession = true; // Removido pois o campo foi removido
    bool notificationPermission = false;
    bool exactAlarmPermission = true; // Assume true por padrão, será atualizado se Android

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

        // A permissão de alarme exato só é relevante no Android
        final bool? androidExactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
        exactAlarmPermission = androidExactAlarmPermission ?? false;
        debugPrint('NotificationService: Android Exact Alarm Permission Granted: $exactAlarmPermission');
      }

      debugPrint('✅ NotificationService: Permissions request finished. Notification: $notificationPermission, Exact Alarm (Android): $exactAlarmPermission');
      return notificationPermission; // Retorna apenas a permissão de notificação geral
    } catch (e) {
      debugPrint('⚠️ NotificationService: Error requesting permissions explicitly: $e');
      return false;
    }
  }

  static void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    debugPrint('NotificationService: Received foreground notification (iOS < 10): ID $id, Title $title');
    // Aqui você pode adicionar lógica para lidar com a notificação recebida enquanto o app está aberto no iOS < 10
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 NotificationService: Notification tapped (foreground/background/terminated): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
    // Adicione aqui a lógica para navegar para a tela correta ou realizar ação com base no payload
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
     debugPrint('♨️ NotificationService: Notification tapped (background isolate): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
     // Lógica para lidar com toque em notificação quando o app está em background (isolado)
     // Cuidado: Acesso limitado a plugins e estado do app aqui.
  }

  static Future<bool> _checkExactAlarmPermission() async {
     if (!_initialized) return false;
     try {
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          // canScheduleExactNotifications retorna null se a permissão não foi concedida ou não é necessária (API < 31)
          final bool? canSchedule = await androidImplementation.canScheduleExactNotifications();
          debugPrint('NotificationService: Check Exact Alarm Permission Result: $canSchedule');
          return canSchedule ?? false; // Retorna false se null (não concedido ou não aplicável)
        }
        return true; // Assume true para outras plataformas (iOS não tem esse conceito)
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
    String? category, // Parâmetro category não está sendo usado aqui, mas mantido por consistência
  }) async {
    debugPrint('NotificationService: Attempting to schedule notification ID $id...');
    if (!_initialized) {
      debugPrint('❌ NotificationService: Cannot schedule, service not initialized.');
      return false;
    }

    try {
      final now = tz.TZDateTime.now(tz.local);
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      // Permitir agendar para alguns segundos no passado para evitar falhas por pequenas diferenças de tempo
      if (tzScheduledDate.isBefore(now.subtract(const Duration(seconds: 10)))) {
        debugPrint('⚠️ NotificationService: Scheduled date $tzScheduledDate is too far in the past. Now: $now');
        return false; // Não agendar se for muito antigo
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
        'reminder_channel_id', // ID do canal
        'Lembretes Importantes', // Nome do canal visível ao usuário
        channelDescription: 'Canal para notificações de lembretes agendados.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker', // Texto que aparece brevemente na barra de status
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.blue, // Cor do LED (se suportado)
        ledOnMs: 1000,
        ledOffMs: 500,
        visibility: NotificationVisibility.public, // Visível na tela de bloqueio
        // actions: [], // Pode adicionar ações aqui se necessário
      );

      // const iosDetails = DarwinNotificationDetails( // REMOVIDO - unused_local_variable
      //   presentAlert: true,
      //   presentBadge: true,
      //   presentSound: true,
      //   // subtitle: 'Subtítulo opcional',
      //   // threadIdentifier: 'lembretes',
      // );

      // CORREÇÃO: Usar DarwinNotificationDetails diretamente no NotificationDetails
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails( // Adicionado aqui
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      debugPrint('NotificationService: Scheduling notification ID $id for $tzScheduledDate with title "$title" (Mode: $scheduleMode)');
      await _notifications.zonedSchedule(
        id,
        title.trim(),
        description.trim().isEmpty ? title.trim() : description.trim(), // Corpo não pode ser vazio
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_$id|${title.trim()}', // Payload útil para identificar a notificação
        matchDateTimeComponents: null, // Não repetir baseado em data/hora
      );

      debugPrint('✅ NotificationService: Notification ID $id scheduled successfully for $tzScheduledDate.');
      await debugInfo(); // Logar estado após agendamento
      return true;
    } catch (e, s) {
      debugPrint('❌ NotificationService: Error scheduling notification ID $id: $e');
      debugPrint('Stack trace: $s');
      if (e.toString().contains('permission') || e.toString().contains('exact_alarms_not_permitted')) {
          debugPrint('NotificationService: Scheduling failed likely due to permissions.');
          // Considerar pedir permissão novamente ou informar o usuário
      }
      return false;
    }
  }

  // Função para agendamento recorrente (exemplo básico, pode precisar de mais lógica)
  static Future<bool> scheduleRecurringNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate, // Primeira ocorrência
    required RepeatInterval repeatInterval,
    String? category,
  }) async {
    debugPrint('NotificationService: Scheduling RECURRING notification ID $id for first occurrence at $scheduledDate, repeating ${repeatInterval.name}');
    // A lógica de recorrência pode ser mais complexa (ex: calcular próxima data)
    // Por simplicidade, vamos apenas agendar a primeira ocorrência aqui.
    // O app precisaria reagendar após cada notificação disparada.
    return await scheduleNotification(
      id: id,
      title: title,
      description: description,
      scheduledDate: scheduledDate,
      category: category,
    );
    // Para recorrência real com flutter_local_notifications, você usaria `periodicallyShow` ou
    // reagendaria manualmente após cada `onDidReceiveNotificationResponse`.
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

  // Checa permissões de forma mais robusta (exemplo)
  static Future<bool> checkNotificationPermissions() async {
     if (!_initialized) return false;
     try {
       // iOS
       final iosImplementation = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
       if (iosImplementation != null) {
         // No iOS >= 10, requestPermissions retorna o status atual se já concedido
         final bool? iosPermissions = await iosImplementation.requestPermissions(alert: true, badge: true, sound: true);
         return iosPermissions ?? false;
       }
       // Android
       final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
       if (androidImplementation != null) {
         // requestNotificationsPermission também pode retornar o status atual
         final bool? androidPermissions = await androidImplementation.requestNotificationsPermission();
         return androidPermissions ?? false;
       }
       return false; // Plataforma não suportada
     } catch (e) {
       debugPrint('⚠️ NotificationService: Error checking notification permissions: $e');
       return false;
     }
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
      debugPrint('   - Permissão de Notificação: ${hasNotificationPermission ? "✅" : "❌"}');
      debugPrint('   - Pode agendar alarmes exatos (Android): ${canScheduleExact ? "✅" : "❌"}');
      debugPrint('   - Agendadas (${scheduled.length}):');

      if (scheduled.isEmpty) {
        debugPrint('     - Nenhuma notificação agendada.');
      } else {
        for (final notification in scheduled) {
          // Usar toString() para obter mais detalhes se disponível
          debugPrint('     - ID: ${notification.id} | Título: ${notification.title} | Payload: ${notification.payload}');
        }
      }
    } catch (e) {
      debugPrint('❌ NotificationService: Error getting debug info: $e');
    }
  }

  // Abre as configurações de notificação do app ou tenta pedir permissão novamente
  static Future<void> openNotificationSettingsOrRequest() async {
    debugPrint('NotificationService: Attempting to open settings or request permission...');
    try {
      // Tenta pedir permissão primeiro
      bool granted = await requestPermissionsIfNeeded();
      if (!granted) {
        debugPrint('NotificationService: Permissions not granted after request. Opening settings might be needed (manual implementation required).');
        // Abrir configurações do app (requer platform channels ou plugin como `permission_handler`)
        // Exemplo com permission_handler (se estivesse instalado):
        // await openAppSettings();
      } else {
        debugPrint('NotificationService: Permissions seem to be granted.');
      }
    } catch (e) {
      debugPrint('❌ NotificationService: Error trying to request permissions/open settings: $e');
    }
  }

  static Future<void> scheduleTestNotification(int seconds) async {
    debugPrint('NotificationService: Scheduling TEST notification in $seconds seconds...');
    final now = DateTime.now();
    await scheduleNotification(
      id: 9999, // ID fixo para teste
      title: '🔔 Teste de Notificação 🔔',
      description: 'Esta é uma notificação de teste agendada para ${seconds}s após ${DateFormat.Hms().format(now)}.', // Corrigido: DateFormat agora está importado
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

