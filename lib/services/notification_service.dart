import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Lembretes',
            channelDescription: 'Canal para lembretes importantes',
            defaultColor: Colors.teal,
            ledColor: Colors.teal,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            criticalAlerts: true,
            defaultRingtoneType: DefaultRingtoneType.Notification,
          ),
          NotificationChannel(
            channelKey: 'recurring_channel',
            channelName: 'Lembretes Recorrentes',
            channelDescription: 'Canal para lembretes que se repetem',
            defaultColor: Colors.orange,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            criticalAlerts: true,
            defaultRingtoneType: DefaultRingtoneType.Notification,
          ),
        ],
        debug: false,
      );
      
      _initialized = true;
      debugPrint('✅ Awesome Notifications inicializado com sucesso'); // ✅ CORRIGIDO
      
      await _checkPermissions();
      
    } catch (e) {
      debugPrint('❌ Erro ao inicializar notificações: $e'); // ✅ CORRIGIDO
      _initialized = false;
    }
  }

  static Future<void> _checkPermissions() async {
    try {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      
      if (!isAllowed) {
        debugPrint('⚠️ Permissão de notificação negada, solicitando...'); // ✅ CORRIGIDO
        final granted = await AwesomeNotifications().requestPermissionToSendNotifications();
        debugPrint('📱 Permissão ${granted ? "concedida" : "negada"}'); // ✅ CORRIGIDO
      }
      
      try {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          permissions: [
            NotificationPermission.Alert,
            NotificationPermission.Sound,
            NotificationPermission.Badge,
            NotificationPermission.Vibration,
            NotificationPermission.Light,
            NotificationPermission.PreciseAlarms,
            NotificationPermission.FullScreenIntent,
            NotificationPermission.CriticalAlert,
          ],
        );
        debugPrint('✅ Permissões de notificação solicitadas'); // ✅ CORRIGIDO
      } catch (e) {
        debugPrint('⚠️ Erro ao solicitar permissões específicas: $e'); // ✅ CORRIGIDO
      }
      
    } catch (e) {
      debugPrint('❌ Erro ao verificar permissões: $e'); // ✅ CORRIGIDO
    }
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
          debugPrint('❌ Não foi possível inicializar o serviço de notificações'); // ✅ CORRIGIDO
          return false;
        }
      }

      final now = DateTime.now();
      if (scheduledDate.isBefore(now.subtract(const Duration(minutes: 1)))) {
        debugPrint('⚠️ Data de agendamento no passado: $scheduledDate'); // ✅ CORRIGIDO
        return false;
      }

      if (title.trim().isEmpty) {
        debugPrint('❌ Título não pode estar vazio'); // ✅ CORRIGIDO
        return false;
      }

      final success = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'basic_channel',
          title: title.trim(),
          body: description.trim().isEmpty ? title.trim() : description.trim(),
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          criticalAlert: true,
          category: NotificationCategory.Reminder,
          autoDismissible: false,
          showWhen: true,
          displayOnForeground: true,
          displayOnBackground: true,
          payload: {
            'id': id.toString(),
            'category': category ?? 'Lembrete',
            'recurring': 'false',
            'type': 'reminder',
          },
        ),
        schedule: NotificationCalendar(
          year: scheduledDate.year,
          month: scheduledDate.month,
          day: scheduledDate.day,
          hour: scheduledDate.hour,
          minute: scheduledDate.minute,
          second: 0,
          millisecond: 0,
          repeats: false,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );

      if (success) {
        debugPrint('✅ Notificação agendada: $title para ${scheduledDate.toString()}'); // ✅ CORRIGIDO
      } else {
        debugPrint('❌ Falha ao agendar notificação: $title'); // ✅ CORRIGIDO
      }

      return success;
    } catch (e) {
      debugPrint('❌ Erro ao agendar notificação: $e'); // ✅ CORRIGIDO
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
    try {
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          debugPrint('❌ Não foi possível inicializar o serviço de notificações'); // ✅ CORRIGIDO
          return false;
        }
      }

      final now = DateTime.now();
      if (scheduledDate.isBefore(now.subtract(const Duration(minutes: 1)))) {
        debugPrint('⚠️ Data de agendamento no passado: $scheduledDate'); // ✅ CORRIGIDO
        return false;
      }

      if (title.trim().isEmpty) {
        debugPrint('❌ Título não pode estar vazio'); // ✅ CORRIGIDO
        return false;
      }

      final success = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'recurring_channel',
          title: title.trim(),
          body: description.trim().isEmpty ? title.trim() : description.trim(),
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          criticalAlert: true,
          category: NotificationCategory.Reminder,
          autoDismissible: false,
          showWhen: true,
          displayOnForeground: true,
          displayOnBackground: true,
          payload: {
            'id': id.toString(),
            'category': category ?? 'Lembrete',
            'recurring': 'true',
            'type': 'reminder',
          },
        ),
        schedule: NotificationCalendar(
          year: scheduledDate.year,
          month: scheduledDate.month,
          day: scheduledDate.day,
          hour: scheduledDate.hour,
          minute: scheduledDate.minute,
          second: 0,
          millisecond: 0,
          repeats: true,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );

      if (success) {
        debugPrint('✅ Notificação recorrente agendada: $title para ${scheduledDate.toString()}'); // ✅ CORRIGIDO
      } else {
        debugPrint('❌ Falha ao agendar notificação recorrente: $title'); // ✅ CORRIGIDO
      }

      return success;
    } catch (e) {
      debugPrint('❌ Erro ao agendar notificação recorrente: $e'); // ✅ CORRIGIDO
      return false;
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await AwesomeNotifications().cancel(id);
      await AwesomeNotifications().cancel(id + 1000);
      debugPrint('🗑️ Notificação cancelada: ID $id'); // ✅ CORRIGIDO
    } catch (e) {
      debugPrint('❌ Erro ao cancelar notificação: $e'); // ✅ CORRIGIDO
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await AwesomeNotifications().cancelAll();
      debugPrint('🗑️ Todas as notificações canceladas'); // ✅ CORRIGIDO
    } catch (e) {
      debugPrint('❌ Erro ao cancelar todas as notificações: $e'); // ✅ CORRIGIDO
    }
  }

  static Future<List<NotificationModel>> getScheduledNotifications() async {
    try {
      final notifications = await AwesomeNotifications().listScheduledNotifications();
      debugPrint('📋 Notificações agendadas: ${notifications.length}'); // ✅ CORRIGIDO
      return notifications;
    } catch (e) {
      debugPrint('❌ Erro ao listar notificações: $e'); // ✅ CORRIGIDO
      return [];
    }
  }

  static Future<bool> hasScheduledNotification(int id) async {
    try {
      final notifications = await getScheduledNotifications();
      return notifications.any((notification) => notification.content?.id == id);
    } catch (e) {
      debugPrint('❌ Erro ao verificar notificação: $e'); // ✅ CORRIGIDO
      return false;
    }
  }

  static Future<bool> isWorking() async {
    try {
      if (!_initialized) return false;
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      return isAllowed;
    } catch (e) {
      debugPrint('❌ Erro ao verificar se está funcionando: $e'); // ✅ CORRIGIDO
      return false;
    }
  }

  static Future<void> debugInfo() async {
    try {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      final scheduled = await getScheduledNotifications();
      
      debugPrint('🔍 DEBUG NOTIFICAÇÕES:'); // ✅ CORRIGIDO
      debugPrint('   - Permissão: ${isAllowed ? "✅" : "❌"}'); // ✅ CORRIGIDO
      debugPrint('   - Inicializado: ${_initialized ? "✅" : "❌"}'); // ✅ CORRIGIDO
      debugPrint('   - Agendadas: ${scheduled.length}'); // ✅ CORRIGIDO
      
      for (final notification in scheduled) {
        debugPrint('   - ID: ${notification.content?.id} | Título: ${notification.content?.title}'); // ✅ CORRIGIDO
      }
    } catch (e) {
      debugPrint('❌ Erro no debug: $e'); // ✅ CORRIGIDO
    }
  }
}