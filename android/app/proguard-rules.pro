# Flutter Local Notifications
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationService { *; }

# Firebase Messaging
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep notification receivers and services
-keep class * extends android.app.NotificationManager { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.app.Service { *; }
-keep class * extends android.app.NotificationChannel { *; }

# Keep widget related classes
-keep class es.antonborri.home_widget.** { *; }

# Keep your custom widget provider
-keep class com.example.jamaat_time.PrayerWidgetProvider { *; }

# Keep timezone related classes
-keep class net.time4j.** { *; }

# General Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep notification channel IDs
-keepclassmembers class * {
    @android.app.NotificationChannel *;
}

# Keep notification sound resources
-keep class android.media.** { *; }

# Prevent obfuscation of notification-related methods
-keepclassmembers class * {
    public void onReceive(android.content.Context, android.content.Intent);
    public void onBootCompleted(android.content.Context, android.content.Intent);
}

# Google Play Core classes (required for Flutter)
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Flutter specific rules
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# Keep all classes in the app package
-keep class com.example.jamaat_time.** { *; }

# Additional Flutter rules
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; } 