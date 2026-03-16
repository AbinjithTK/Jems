# Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core (required by Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
