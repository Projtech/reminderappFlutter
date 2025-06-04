# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mantenha as classes do Firebase Cloud Messaging (FCM) se você estiver usando o Firebase
# -keep class com.google.firebase.messaging.** { *; }
# -keep class com.google.android.gms.tasks.** { *; }

# Adicione regras para outras bibliotecas de notificação, se necessário

# Mantenha sua classe Application personalizada, se houver
# -keep class com.example.reminderflutter.Application { *; }

# Mantenha seu BroadcastReceiver personalizado, se usado para notificações
# -keep class com.example.reminderflutter.NotificationReceiver { *; }

# Mantenha quaisquer classes usadas via reflexão para notificações

# Regras adicionadas para Google Play Core (erro R8)
-keep class com.google.android.play.core.** { *; }

