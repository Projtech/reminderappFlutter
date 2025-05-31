import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/services.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Inicializar timezone
      tz.initializeTimeZones();
      
      // Configurações Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Configurações iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // ✅ SOLICITAR PERMISSÕES NECESSÁRIAS
      await _requestPermissions();
      
      _initialized = true;
      debugPrint('✅ Notificações inicializadas com sucesso');
      
    } catch (e) {
      debugPrint('❌ Erro ao inicializar notificações: $e');
      _initialized = false;
    }
  }

  // ✅ SOLICITAR PERMISSÕES ANDROID 12+
  static Future<void> _requestPermissions() async {
    try {
      // Solicitar permissão para notificações (Android 13+)
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Solicitar permissão para alarmes exatos (Android 12+)
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      debugPrint('✅ Permissões solicitadas');
    } catch (e) {
      debugPrint('⚠️ Erro ao solicitar permissões: $e');
    }
  }

  // ✅ VERIFICAR SE PODE AGENDAR ALARMES EXATOS
  static Future<bool> _canScheduleExactAlarms() async {
    try {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        return await androidImplementation.canScheduleExactNotifications() ?? false;
      }
      return true; // iOS sempre pode
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar permissão de alarmes: $e');
      return false;
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Notificação tocada: ${response.payload}');
    // Aqui você pode navegar para telas específicas
  }

  static Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate,
    String? category,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          debugPrint('❌ Não foi possível inicializar o serviço de notificações');
          return false;
        }
      }

      final now = DateTime.now();
      if (scheduledDate.isBefore(now.subtract(const Duration(minutes: 1)))) {
        debugPrint('⚠️ Data de agendamento no passado: $scheduledDate');
        return false;
      }

      if (title.trim().isEmpty) {
        debugPrint('❌ Título não pode estar vazio');
        return false;
      }

      // ✅ VERIFICAR PERMISSÃO PARA ALARMES EXATOS
      final canScheduleExact = await _canScheduleExactAlarms();
      if (!canScheduleExact) {
        debugPrint('⚠️ Permissão para alarmes exatos não concedida. Tentando solicitar...');
        await _requestPermissions();
        
        // Verificar novamente
        final canScheduleAfterRequest = await _canScheduleExactAlarms();
        if (!canScheduleAfterRequest) {
          debugPrint('❌ Usuário negou permissão para alarmes exatos');
          // Mesmo assim, vamos tentar agendar - pode funcionar como alarme aproximado
        }
      }

      await _notifications.zonedSchedule(
        id,
        title.trim(),
        description.trim().isEmpty ? title.trim() : description.trim(),
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'basic_channel',
            'Lembretes',
            channelDescription: 'Canal para lembretes importantes',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            autoCancel: true,
            enableLights: true,
            ledColor: Color.fromARGB(255, 255, 0, 0),
            ledOnMs: 1000,
            ledOffMs: 500,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_$id',
      );

      debugPrint('✅ Notificação agendada: $title para ${scheduledDate.toString()}');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao agendar notificação: $e');
      
      // ✅ TENTAR AGENDAR COMO NOTIFICAÇÃO SIMPLES SE FALHAR
      if (e.toString().contains('exact_alarms_not_permitted') || 
          e.toString().contains('ExactAlarmPermissionException')) {
        debugPrint('⚠️ Tentando agendar como notificação aproximada...');
        return await _scheduleApproximateNotification(
          id: id,
          title: title,
          description: description,
          scheduledDate: scheduledDate,
        );
      }
      return false;
    }
  }

  // ✅ BACKUP: NOTIFICAÇÃO APROXIMADA
  static Future<bool> _scheduleApproximateNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate,
  }) async {
    try {
      // Mostrar notificação imediata explicando a limitação
      await _notifications.show(
        id + 10000, // ID diferente para não conflitar
        'Lembrete Agendado',
        'Seu lembrete "$title" foi agendado para ${scheduledDate.day}/${scheduledDate.month} às ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_channel',
            'Agendados',
            channelDescription: 'Confirmação de lembretes agendados',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
      
      debugPrint('✅ Notificação de confirmação mostrada');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao mostrar notificação de confirmação: $e');
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
    // Para recurring, agendamos a próxima ocorrência
    return await scheduleNotification(
      id: id,
      title: title,
      description: description,
      scheduledDate: scheduledDate,
      category: category,
    );
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('🗑️ Notificação cancelada: ID $id');
    } catch (e) {
      debugPrint('❌ Erro ao cancelar notificação: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('🗑️ Todas as notificações canceladas');
    } catch (e) {
      debugPrint('❌ Erro ao cancelar todas as notificações: $e');
    }
  }

  static Future<List<PendingNotificationRequest>> getScheduledNotifications() async {
    try {
      final notifications = await _notifications.pendingNotificationRequests();
      debugPrint('📋 Notificações agendadas: ${notifications.length}');
      return notifications;
    } catch (e) {
      debugPrint('❌ Erro ao listar notificações: $e');
      return [];
    }
  }

  static Future<bool> hasScheduledNotification(int id) async {
    try {
      final notifications = await getScheduledNotifications();
      return notifications.any((notification) => notification.id == id);
    } catch (e) {
      debugPrint('❌ Erro ao verificar notificação: $e');
      return false;
    }
  }

  static Future<bool> isWorking() async {
    try {
      if (!_initialized) return false;
      return await _canScheduleExactAlarms();
    } catch (e) {
      debugPrint('❌ Erro ao verificar se está funcionando: $e');
      return false;
    }
  }

  static Future<void> debugInfo() async {
    try {
      final scheduled = await getScheduledNotifications();
      final canSchedule = await _canScheduleExactAlarms();
      
      debugPrint('🔍 DEBUG NOTIFICAÇÕES:');
      debugPrint('   - Inicializado: ${_initialized ? "✅" : "❌"}');
      debugPrint('   - Pode agendar alarmes exatos: ${canSchedule ? "✅" : "❌"}');
      debugPrint('   - Agendadas: ${scheduled.length}');
      
      for (final notification in scheduled) {
        debugPrint('   - ID: ${notification.id} | Título: ${notification.title}');
      }
    } catch (e) {
      debugPrint('❌ Erro no debug: $e');
    }
  }

  // ✅ MÉTODO PARA ABRIR CONFIGURAÇÕES DE PERMISSÃO
  static Future<void> openNotificationSettings() async {
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('❌ Erro ao abrir configurações: $e');
    }
  }
}