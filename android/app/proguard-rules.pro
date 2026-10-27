# Suppress ML Kit optional language recognizers warnings for R8
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }