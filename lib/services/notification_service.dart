
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
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

      await _createAndroidNotificationChannel();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

  @pragma('vm:entry-point')
  static Future<void> _createAndroidNotificationChannel() async {
    try {
      await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.deleteNotificationChannel('reminder_channel_id');
      debugPrint('🗑️ NotificationService: Deleted old channel.');
    } catch (e) {
      debugPrint('NotificationService: No old channel to delete: $e');
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
       debugPrint('✅ NotificationService: HEADS-UP channel created (MAX + SOUND + VIBRATION, no LED).');
    } catch (e) {
       debugPrint('❌ NotificationService: Failed to create heads-up channel: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<Map<Permission, PermissionStatus>> requestCorePermissions() async {
    if (!_initialized) {
       debugPrint('NotificationService: Cannot request permissions, service not initialized.');
       return {};
    }
    debugPrint('NotificationService: Requesting core permissions using permission_handler...');
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.scheduleExactAlarm
    ].request();

    debugPrint('NotificationService: Permission statuses after request:');
    statuses.forEach((permission, status) {
      debugPrint('  ${permission.toString()}: ${status.toString()}');
    });

    return statuses;
  }

  @pragma('vm:entry-point')
  static Future<bool> checkNotificationPermissionStatus() async {
      PermissionStatus status = await Permission.notification.status;
      debugPrint('NotificationService: Current Notification Permission Status: $status');
      return status.isGranted;
  }

  @pragma('vm:entry-point')
  static Future<bool> checkExactAlarmPermissionStatus() async {
      PermissionStatus status = await Permission.scheduleExactAlarm.status;
      debugPrint('NotificationService: Current Schedule Exact Alarm Permission Status: $status');
      return status.isGranted || status.isLimited; 
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 NotificationService: Notification tapped (foreground/background/terminated): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
     debugPrint('♨️ NotificationService: Notification tapped (background isolate): Payload: ${response.payload}, ActionId: ${response.actionId}, Input: ${response.input}');
  }

  @pragma('vm:entry-point')
  static Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String description,
    required DateTime scheduledDate,
    String? category,
  }) async {
    debugPrint('NotificationService: Attempting to schedule HEADS-UP notification ID $id for $scheduledDate...');
    if (!_initialized) {
      debugPrint('❌ NotificationService: Cannot schedule, service not initialized.');
      return false;
    }

    bool hasNotificationPerm = await checkNotificationPermissionStatus();
    if (!hasNotificationPerm) {
        debugPrint('❌ NotificationService: Notification permission denied for ID $id. Cannot schedule.');
        return false;
    }

    bool canScheduleExact = await checkExactAlarmPermissionStatus();
    AndroidScheduleMode scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    debugPrint('NotificationService: Scheduling ID $id with ${canScheduleExact ? "EXACT" : "INEXACT" } alarm mode.');

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzScheduledDate.isBefore(now.subtract(const Duration(seconds: 2)))) { 
        debugPrint('❌ NotificationService: Scheduled date $tzScheduledDate for ID $id is in the past (Now: $now). Skipping schedule.');
        return false;
      }
      if (title.trim().isEmpty) {
        debugPrint('❌ NotificationService: Title cannot be empty for ID $id. Skipping schedule.');
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
        
        timeoutAfter: 5000,
        autoCancel: true,
        
        when: DateTime.now().millisecondsSinceEpoch,
        showWhen: true,
        ticker: title.trim(),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      debugPrint('NotificationService: CORRECTED HEADS-UP AndroidDetails for ID $id:');
      debugPrint('  - channelId: ${androidDetails.channelId}');
      debugPrint('  - importance: ${androidDetails.importance.toString()} (MAX)');
      debugPrint('  - priority: ${androidDetails.priority.toString()} (MAX)');
      debugPrint('  - playSound: ${androidDetails.playSound} (REQUIRED for heads-up)');
      debugPrint('  - enableVibration: ${androidDetails.enableVibration} (REQUIRED for heads-up)');
      debugPrint('  - category: ${androidDetails.category.toString()} (ALARM)');
      debugPrint('  - timeoutAfter: ${androidDetails.timeoutAfter} (auto-remove)');

      debugPrint('NotificationService: Calling zonedSchedule for CORRECTED HEADS-UP notification ID $id');
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

      debugPrint('✅ NotificationService: CORRECTED HEADS-UP notification ID $id scheduled successfully.');
      await debugInfo();
      return true;
    } catch (e, s) {
      debugPrint('❌ NotificationService: Error scheduling heads-up notification ID $id: $e');
      debugPrint('Stack trace: $s');
      if (e.toString().contains('permission') || e.toString().contains('exact_alarms_not_permitted')) {
          debugPrint('NotificationService: Scheduling failed likely due to permissions for ID $id.');
      }
      return false;
    }
  }

  @pragma('vm:entry-point')
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

  @pragma('vm:entry-point')
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

  @pragma('vm:entry-point')
  static Future<List<PendingNotificationRequest>> getScheduledNotifications() async {
    if (!_initialized) return [];
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ NotificationService: Error listing scheduled notifications: $e');
      return [];
    }
  }

  @pragma('vm:entry-point')
  static Future<void> debugInfo() async {
    if (!_initialized) {
       debugPrint('🔍 DEBUG NOTIFICAÇÕES: Service not initialized.');
       return;
    }
    try {
      final scheduled = await getScheduledNotifications();
      final hasNotificationPermission = await checkNotificationPermissionStatus();
      final canScheduleExact = await checkExactAlarmPermissionStatus();

      debugPrint('🔍 --- DEBUG HEADS-UP CORRIGIDO ---');
      debugPrint('   - Inicializado: ✅');
      debugPrint('   - Canal: $_channelId (SEM LED - corrigido)');
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
      debugPrint('🔍 --- FIM DEBUG HEADS-UP CORRIGIDO ---');

    } catch (e) {
      debugPrint('❌ NotificationService: Error getting debug info: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> openSettingsAndRequestPermissions() async {
    debugPrint('NotificationService: Checking permissions and potentially opening settings...');
    Map<Permission, PermissionStatus> statuses = await requestCorePermissions();
    
    bool allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);

    if (!allGranted) {
        debugPrint('NotificationService: Not all permissions granted. Opening app settings...');
        bool didOpen = await openAppSettings();
        if (!didOpen) {
            debugPrint('NotificationService: Could not open app settings.');
        }
    } else {
        debugPrint('NotificationService: All required permissions seem to be granted.');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> scheduleTestNotification(int seconds) async {
    debugPrint('NotificationService: Scheduling CORRECTED HEADS-UP TEST in $seconds seconds...');
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
    debugPrint('🚨 CONFIGURAÇÕES OBRIGATÓRIAS MOTOROLA EDGE 20 PRO:');
    debugPrint('');
    debugPrint('📱 1. CONFIGURAÇÕES DO APP:');
    debugPrint('   Configurações > Apps > Seus Lembretes > Notificações');
    debugPrint('   ✅ Ativar "Mostrar na tela" ou "Pop-up na tela"');
    debugPrint('   ✅ Ativar "Som" e "Vibração"');
    debugPrint('');
    debugPrint('🔇 2. NÃO PERTURBE:');
    debugPrint('   Configurações > Som > Não perturbe = DESLIGADO');
    debugPrint('');
    debugPrint('📺 3. MOTO DISPLAY:');
    debugPrint('   Configurações > Display > Moto Display > Notificações = ATIVADO');
    debugPrint('');
    debugPrint('🔋 4. OTIMIZAÇÃO DE BATERIA (CRÍTICO):');
    debugPrint('   Configurações > Bateria > Otimização de bateria');
    debugPrint('   Procurar "Seus Lembretes" > NÃO OTIMIZAR');
    debugPrint('');
    debugPrint('🔔 5. IMPORTANTE:');
    debugPrint('   - Heads-up SÓ aparecem com SOM + VIBRAÇÃO');
    debugPrint('   - Heads-up SÓ aparecem com TELA LIGADA');
    debugPrint('   - App MINIMIZADO: deve funcionar');
    debugPrint('   - App FECHADO: pode não funcionar (Android otimiza)');
    debugPrint('');
  }

  @pragma('vm:entry-point')
  static Future<void> requestBatteryOptimizationDisable() async {
    debugPrint('🔋 Verificando otimização de bateria...');
    
    try {
      PermissionStatus status = await Permission.ignoreBatteryOptimizations.status;
      debugPrint('Status atual da otimização de bateria: $status');
      
      if (!status.isGranted) {
        debugPrint('🔋 Solicitando permissão para ignorar otimização de bateria...');
        PermissionStatus newStatus = await Permission.ignoreBatteryOptimizations.request();
        debugPrint('Novo status: $newStatus');
        
        if (!newStatus.isGranted) {
          debugPrint('⚠️ Usuário negou. Abrindo configurações...');
          debugPrint('⚠️ MANUALMENTE: Configurações > Bateria > Otimização > Seus Lembretes > NÃO OTIMIZAR');
          await openAppSettings();
        } else {
          debugPrint('✅ Otimização de bateria desabilitada com sucesso!');
        }
      } else {
        debugPrint('✅ Otimização de bateria já está desabilitada!');
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar otimização de bateria: $e');
      debugPrint('⚠️ CONFIGURE MANUALMENTE: Configurações > Bateria > Otimização > Seus Lembretes > NÃO OTIMIZAR');
      await openAppSettings();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> testeGradualNotificacoes() async {
    debugPrint('');
    debugPrint('🧪 ========================================');
    debugPrint('🧪 INICIANDO TESTE GRADUAL DE NOTIFICAÇÕES');
    debugPrint('🧪 ========================================');
    debugPrint('');
    
    // 1. Verificar configurações primeiro
    await checkMotorolaSettings();
    
    debugPrint('🧪 TESTE 1: APP MINIMIZADO (10 segundos)');
    debugPrint('');
    debugPrint('📋 INSTRUÇÕES:');
    debugPrint('   1. Leia estas instruções');
    debugPrint('   2. Pressione o botão HOME (minimizar app)');
    debugPrint('   3. NÃO feche o app pelo recent apps');
    debugPrint('   4. Aguarde 10 segundos');
    debugPrint('   5. A notificação deve aparecer COM POPUP');
    debugPrint('');
    debugPrint('⏰ Agendando notificação para 10 segundos...');
    
    await scheduleTestNotification(10);
    
    debugPrint('✅ Notificação agendada! MINIMIZE O APP AGORA!');
    debugPrint('');
  }

  @pragma('vm:entry-point')
  static Future<void> testeComAppFechado() async {
    debugPrint('');
    debugPrint('🧪 ========================================');
    debugPrint('🧪 TESTE 2: APP COMPLETAMENTE FECHADO');
    debugPrint('🧪 ========================================');
    debugPrint('');
    
    debugPrint('🧪 TESTE 2: APP FECHADO (15 segundos)');
    debugPrint('');
    debugPrint('📋 INSTRUÇÕES:');
    debugPrint('   1. Leia estas instruções');
    debugPrint('   2. Abra Recent Apps (botão quadrado)');
    debugPrint('   3. FECHE o app deslizando para cima');
    debugPrint('   4. Aguarde 15 segundos');
    debugPrint('   5. A notificação deve aparecer');
    debugPrint('');
    debugPrint('⚠️ AVISO: Este teste pode falhar devido às');
    debugPrint('   otimizações agressivas do Android.');
    debugPrint('');
    debugPrint('⏰ Agendando notificação para 15 segundos...');
    
    await scheduleTestNotification(15);
    
    debugPrint('✅ Notificação agendada! FECHE O APP AGORA!');
    debugPrint('');
  }

  @pragma('vm:entry-point')
  static Future<void> testeComTelaLigada() async {
    debugPrint('');
    debugPrint('🧪 ========================================');
    debugPrint('🧪 TESTE 3: HEADS-UP COM TELA LIGADA');
    debugPrint('🧪 ========================================');
    debugPrint('');
    
    debugPrint('🧪 TESTE 3: HEADS-UP DISPLAY (8 segundos)');
    debugPrint('');
    debugPrint('📋 INSTRUÇÕES:');
    debugPrint('   1. DEIXE A TELA LIGADA');
    debugPrint('   2. Minimize o app (botão HOME)');
    debugPrint('   3. Aguarde 8 segundos');
    debugPrint('   4. O POPUP deve aparecer NA TELA');
    debugPrint('');
    debugPrint('🔔 OBJETIVO: Testar se o heads-up aparece');
    debugPrint('   com tela ligada (condição obrigatória)');
    debugPrint('');
    debugPrint('⏰ Agendando notificação para 8 segundos...');
    
    await scheduleTestNotification(8);
    
    debugPrint('✅ Notificação agendada!');
    debugPrint('🔆 MANTENHA A TELA LIGADA E MINIMIZE O APP!');
    debugPrint('');
  }
}