# Règles pour Google ML Kit (Text Recognition)
-keep class com.google.mlkit.vision.text.** { *; }
-keepclassmembers class com.google.mlkit.vision.text.** { *; }

-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
-keepclassmembers class com.google.android.gms.internal.mlkit_vision_text.** { *; }

# --- CORRECTION ---
# Indique à R8 d'ignorer les avertissements pour les packs de 
# langues optionnels que nous n'utilisons pas.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**