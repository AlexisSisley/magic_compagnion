plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.magic_companion"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.magic_companion"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Par défaut (pour la release), le nom est "Magic Companion"
        resValue("string", "app_name", "Magic Companion")
    }

    buildTypes {
        getByName("debug") {
            // --- CONFIGURATION DEBUG ---
            // Ajoute un suffixe à l'ID pour installer l'app à côté de la version release
            applicationIdSuffix = ".debug"

            // Change le nom pour la version debug (avec un emoji ou un texte)
            resValue("string", "app_name", "Magic Dev 🛠️")

            // Signature de debug standard
            signingConfig = signingConfigs.getByName("debug")

        }

        getByName("release") {
            // Votre CI utilise la signature de debug, ce qui est parfait
            signingConfig = signingConfigs.getByName("debug")    
            // Indique les fichiers de règles 
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
