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

# Google ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }
