# Disable aggressive R8 optimizations to prevent lifecycle inlining
-dontoptimize

# Suppress Play Store deferred components warning
-dontwarn com.google.android.play.core.**

# Flutter & Application keep rules
-keep class io.flutter.** { *; }
-keep class com.lenglish.l_english.** { *; }

# Shorebird Updater
-dontwarn dev.shorebird.**
-keep class dev.shorebird.** { *; }

# Google ML Kit & Play Services Components (Required for MlKitInitProvider on launch)
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

-keep public class * implements com.google.firebase.components.ComponentRegistrar
-keep class com.google.firebase.components.** { *; }
-dontwarn com.google.firebase.components.**
