# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Suppress R8 missing-class warnings ────────────────────────────────────────
# AutoValue / JavaPoet (shaded annotation processor deps)
-dontwarn javax.lang.model.**
-dontwarn autovalue.shaded.**
-dontwarn com.squareup.javapoet.**

# MediaPipe / flutter_gemma (uses internal protobuf annotations)
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.ProtoField
-dontwarn com.google.protobuf.ProtoPresenceBits
-dontwarn com.google.protobuf.ProtoPresenceCheckedField
-dontwarn com.google.protobuf.**

# Keep all MediaPipe classes (Gemma LLM inference JNI)
-keep class com.google.mediapipe.** { *; }
-keepclassmembers class com.google.mediapipe.** { *; }

# Keep all protobuf generated classes
-keep class com.google.protobuf.** { *; }
-keepclassmembers class com.google.protobuf.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# SQLite / SQFlite
-keep class com.tekartik.sqflite.** { *; }

# General
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepclassmembers class * {
    native <methods>;
}
