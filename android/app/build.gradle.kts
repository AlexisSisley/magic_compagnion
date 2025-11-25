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

    signingConfigs {
        create("release") {
            // 1. Essayer de lire les variables d'environnement (CI GitHub)
            val envStorePass = System.getenv("KEYSTORE_STORE_PASSWORD")
            val envKeyPass = System.getenv("KEYSTORE_KEY_PASSWORD")
            val envKeyAlias = System.getenv("KEYSTORE_KEY_ALIAS")
            val envStorePath = System.getenv("KEYSTORE_PATH")

            if (envStorePass != null && envKeyPass != null && envKeyAlias != null && envStorePath != null) {
                storeFile = file(envStorePath)
                storePassword = envStorePass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            }
            // 2. Sinon, utiliser le fichier local key.properties (Dev local)
            else if (keystoreProperties["storePassword"] != null) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
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
            // Utilise la configuration "release" définie ci-dessus
            signingConfig = signingConfigs.getByName("release")
            
            // Optimisation et obfuscation (optionnel mais recommandé)
            isMinifyEnabled = true 
            isShrinkResources = true
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
