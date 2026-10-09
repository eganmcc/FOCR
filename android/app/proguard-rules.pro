# ML Kit text recognition: only the Latin model is bundled. The plugin references the optional
# Chinese/Devanagari/Japanese/Korean recognizers, which R8 would otherwise flag as missing.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit wires its internal components (vision-common, text-recognition, telemetry) by
# reflection. R8 stripping them makes InputImage.fromFilePath throw an NPE in release builds
# (seen 2026-10-09 on a Xiaomi 24115RA8EG; debug builds were unaffected).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
