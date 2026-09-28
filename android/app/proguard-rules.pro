# Flutter embedding and plugin entry points.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Messaging background handlers and generated registrants are resolved reflectively.
-keep class com.google.firebase.messaging.** { *; }
-dontwarn io.flutter.embedding.**
