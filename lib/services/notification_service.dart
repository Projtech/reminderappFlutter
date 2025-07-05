import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

class NotificationService {
static final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();
static bool _initialized = false;
static const String _channelId = 'heads_up_urgent_channel';
static const String _channelName = 'Heads-Up Urgentes';
static const String _channelDescription = 'Notificações que aparecem na tela com som.';
static const int _maxScheduledNotifications = 15; // LIMITE DE AGENDAMENTOS
// CANAL PARA ATUALIZAÇÕES
static const String _updateChannelId = 'app_update_channel';
static const String _updateChannelName = 'Atualizações do App';
static const String _updateChannelDescription = 'Notificações sobre novas versões disponíveis';

@pragma('vm:entry-point')
static Future<void> initialize() async {
  if (_initialized) return;
  
  try {
    tz.initializeTimeZones();
    try {
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await _createAndroidNotificationChannel();
    await _createUpdateNotificationChannel();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    final bool? didInitialize = await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    _initialized = didInitialize ?? false;
  } catch (e) {
    _initialized = false;
  }
}

@pragma('vm:entry-point')
static Future<void> _createAndroidNotificationChannel() async {
  try {
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel('reminder_channel_id');
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
     await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
         ?.createNotificationChannel(androidChannel);
  } catch (e) {
    // Ignore creation errors
  }
}

@pragma('vm:entry-point')
static Future<Map<Permission, PermissionStatus>> requestCorePermissions() async {
  if (!_initialized) return {};
  
  Map<Permission, PermissionStatus> statuses = await [
    Permission.notification,
    Permission.scheduleExactAlarm
  ].request();

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
static Future<bool> isBatteryOptimizationDisabled() async {
  try {
    PermissionStatus status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  } catch (e) {
    return false;
  }
}

@pragma('vm:entry-point')
static Future<void> _onNotificationTapped(NotificationResponse response) async {
  final payload = response.payload;
  
  // Verificar se é notificação de update
  if (payload != null && payload.startsWith('whats_new:')) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_whats_new_on_open', true);
    await prefs.setString('whats_new_version', payload.split(':')[1]);
  }
  
  // Para outros tipos de notificação, manter comportamento atual
}

@pragma('vm:entry-point')
static void _onBackgroundNotificationTapped(NotificationResponse response) {
  // Pode implementar navegação específica aqui
}

// NOVO: AGENDAR MÚLTIPLAS NOTIFICAÇÕES PARA UM LEMBRETE
@pragma('vm:entry-point')
static Future<bool> scheduleReminderNotifications(Reminder reminder) async {
  if (!_initialized) return false;

  bool hasNotificationPerm = await checkNotificationPermissionStatus();
  if (!hasNotificationPerm) return false;

  final now = DateTime.now();
  
  if (reminder.isRecurring && reminder.recurringType != null && reminder.recurringType != 'none') {
    //  AGENDAR MÚLTIPLAS OCORRÊNCIAS
    final occurrences = reminder.getNextOccurrences(_maxScheduledNotifications);
    int scheduledCount = 0;
    
    for (int i = 0; i < occurrences.length; i++) {
      final occurrence = occurrences[i];
      if (occurrence.isAfter(now.subtract(const Duration(seconds: 5)))) {
        final notificationId = _generateRecurrenceId(reminder.id!, i);
        final success = await _scheduleIndividualNotification(
          id: notificationId,
          title: '🔄 ${reminder.title}',
          description: reminder.description,
          scheduledDate: occurrence,
          category: reminder.category,
        );
        if (success) scheduledCount++;
      }
    }
    
    return scheduledCount > 0;
  } else {
    //  AGENDAMENTO ÚNICO
    if (reminder.dateTime.isAfter(now.subtract(const Duration(seconds: 5)))) {
      return await _scheduleIndividualNotification(
        id: reminder.id!,
        title: reminder.title,
        description: reminder.description,
        scheduledDate: reminder.dateTime,
        category: reminder.category,
      );
    }
  }
  
  return false;
}

//  GERAR IDs ÚNICOS PARA REPETIÇÕES (evita conflitos)
static int _generateRecurrenceId(int reminderId, int occurrenceIndex) {
  // Combina o ID do lembrete com o índice da ocorrência
  // Ex: reminder ID 123, occurrence 5 = 1235 (limitado a 999 ocorrências)
  return (reminderId * 1000) + (occurrenceIndex % 1000);
}

// CANCELAR TODAS AS NOTIFICAÇÕES DE UM LEMBRETE
@pragma('vm:entry-point')
static Future<void> cancelReminderNotifications(int reminderId) async {
  if (!_initialized) return;
  
  try {
    // Cancelar notificação principal
    await _notifications.cancel(reminderId);
    
    // Cancelar todas as possíveis repetições
    for (int i = 0; i < _maxScheduledNotifications; i++) {
      final recurrenceId = _generateRecurrenceId(reminderId, i);
      await _notifications.cancel(recurrenceId);
    }
  } catch (e) {
    // Ignore cancellation errors
  }
}

// MÉTODO INTERNO PARA AGENDAMENTO INDIVIDUAL
@pragma('vm:entry-point')
static Future<bool> _scheduleIndividualNotification({
  required int id,
  required String title,
  required String description,
  required DateTime scheduledDate,
  String? category,
}) async {
  if (!_initialized) return false;

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
    if (title.trim().isEmpty) return false;

    final androidDetails = AndroidNotificationDetails(
      _channelId, 
      _channelName, 
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      autoCancel: true,
      ongoing: false,
      when: null,
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
    );

    return true;
  } catch (e) {
    return false;
  }
}

// COMPATIBILIDADE: Manter método antigo
@pragma('vm:entry-point')
static Future<bool> scheduleNotification({
  required int id,
  required String title,
  required String description,
  required DateTime scheduledDate,
  String? category,
}) async {
  return await _scheduleIndividualNotification(
    id: id,
    title: title,
    description: description,
    scheduledDate: scheduledDate,
    category: category,
  );
}

// COMPATIBILIDADE: Manter método antigo
@pragma('vm:entry-point')
static Future<void> cancelNotification(int id) async {
  await cancelReminderNotifications(id);
}

@pragma('vm:entry-point')
static Future<void> cancelAllNotifications() async {
  if (!_initialized) return;
  try {
    await _notifications.cancelAll();
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
static Future<void> openSettingsAndRequestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await requestCorePermissions();
  
  bool allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);

  if (!allGranted) {
      await openAppSettings();
  }
}

@pragma('vm:entry-point')
static Future<void> requestBatteryOptimizationDisable() async {
  try {
    PermissionStatus status = await Permission.ignoreBatteryOptimizations.status;
    
    if (!status.isGranted) {
      PermissionStatus newStatus = await Permission.ignoreBatteryOptimizations.request();
      
      if (!newStatus.isGranted) {
        await openAppSettings();
      }
    }
  } catch (e) {
    await openAppSettings();
  }
}

@pragma('vm:entry-point')
static Future<void> scheduleTestNotification(int seconds) async {
  final now = DateTime.now();
  await scheduleNotification(
    id: 9999, 
    title: '🚨 TESTE DE REPETIÇÕES 🚨',
    description: 'Sistema de repetições funcionando!',
    scheduledDate: now.add(Duration(seconds: seconds)),
  );
}
// CRIAR CANAL DE ATUALIZAÇÕES
@pragma('vm:entry-point')
static Future<void> _createUpdateNotificationChannel() async {
  const updateChannel = AndroidNotificationChannel(
    _updateChannelId,
    _updateChannelName,
    description: _updateChannelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );
  
  try {
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(updateChannel);
  } catch (e) {
    // Ignore creation errors
  }
}

// NOTIFICAÇÃO DE ATUALIZAÇÃO
@pragma('vm:entry-point')
static Future<void> showUpdateNotification(Map<String, dynamic> updateInfo) async {
  if (!_initialized) return;
  
  final version = updateInfo['version'] ?? 'Nova versão';
  final whatsNew = updateInfo['whatsNew'] ?? {};
  final items = whatsNew['items'] ?? [];
  
  // Contar novidades por categoria
  int newCount = items.where((item) => item['category'] == 'new').length;
  int improvedCount = items.where((item) => item['category'] == 'improved').length;
  int fixedCount = items.where((item) => item['category'] == 'fixed').length;
  
  String description = '';
  if (newCount > 0) description += '🆕 $newCount novidades';
  if (improvedCount > 0) description += '${description.isNotEmpty ? ', ' : ''}⚡ $improvedCount melhorias';
  if (fixedCount > 0) description += '${description.isNotEmpty ? ', ' : ''}🐛 $fixedCount correções';
  
  if (description.isEmpty) description = 'Toque para ver todas as novidades';
  
  final androidDetails = AndroidNotificationDetails(
    _updateChannelId,
    _updateChannelName,
    channelDescription: _updateChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    autoCancel: true,
    ongoing: false,
    ticker: 'Seus Lembretes - Atualização $version!',
  );
  
  final notificationDetails = NotificationDetails(android: androidDetails);
  
  await _notifications.show(
    99999, // ID fixo para atualizações
    'Seus Lembretes - Atualização $version!',
    description,
    notificationDetails,
    payload: 'whats_new:$version',
  );
}
}