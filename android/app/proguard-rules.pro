# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Local Notifications - CRÍTICO para release mode
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson (usado por flutter_local_notifications)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.** { *; }
-keep class * extends com.google.gson.** { *; }

# Shared Preferences
-keep class androidx.preference.** { *; }
-keep class android.content.SharedPreferences** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Timezone
-keep class com.example.timezone.** { *; }
-keep class org.threeten.** { *; }
-dontwarn org.threeten.**

# Android Notification classes
-keep class android.app.Notification** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class android.app.AlarmManager** { *; }
-keep class android.app.PendingIntent** { *; }

# Manter callbacks de notificação
-keep class * {
    void onDidReceiveNotificationResponse(...);
    void onDidReceiveBackgroundNotificationResponse(...);
}

# Regras adicionadas para Google Play Core
-keep class com.google.android.play.core.** { *; }

# Manter classes de reflection usadas por plugins
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Evitar removal de métodos callback
-keepclassmembers class * {
    public void onMethodCall(...);
    public void success(...);
    public void error(...);
    public void notImplemented();
}