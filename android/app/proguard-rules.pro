# Règles pour Google ML Kit (Text Recognition)
-keep class com.google.mlkit.vision.text.** { *; }
-keepclassmembers class com.google.mlkit.vision.text.** { *; }

-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keepclassmembers class com.google.android.gms.internal.mlkit_vision_text.** { *; }

# Garde spécifiquement les modèles de langue que R8 supprime
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }