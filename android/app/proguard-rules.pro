# Flutter wrapper and platform channels
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep flutter_local_notifications & Gson classes for R8 / ProGuard in release builds
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature, InnerClasses, EnclosingMethod, RuntimeVisibleAnnotations, *Annotation*

# Keep Google Play Core classes if referenced by deferred components
-dontwarn com.google.android.play.core.**
