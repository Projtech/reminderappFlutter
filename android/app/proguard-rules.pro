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

-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-dontwarn io.supabase.**
-dontwarn com.supabase.**

# HTTP Client (usado pelo Supabase)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# JSON Serialization (crítico para API calls)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class * implements java.io.Serializable { *; }
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# WebSocket Support (usado pelo Supabase Realtime)
-keep class org.java_websocket.** { *; }
-dontwarn org.java_websocket.**

# Device Info Plugin (usado no ReportService)
-keep class io.flutter.plugins.deviceinfo.** { *; }
-dontwarn io.flutter.plugins.deviceinfo.**

# Package Info Plugin (usado no ReportService)
-keep class io.flutter.plugins.packageinfo.** { *; }
-dontwarn io.flutter.plugins.packageinfo.**

# SSL/TLS Classes (crítico para HTTPS)
-keep class javax.net.ssl.** { *; }
-keep class javax.security.** { *; }
-dontwarn javax.net.ssl.**
-dontwarn javax.security.**

# Manter todas as classes relacionadas ao networking
-keep class java.net.** { *; }
-keep class java.nio.** { *; }
-dontwarn java.net.**
-dontwarn java.nio.**