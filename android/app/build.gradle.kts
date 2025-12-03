plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. IMPORTS OBLIGATOIRES ICI
import java.util.Properties
import java.io.FileInputStream

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
        applicationId = "com.example.magic_companion"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Magic Companion")
    }

    signingConfigs {
        create("release") {
            // 2. RECUPERATION DES VARIABLES CI
            val envStorePass = System.getenv("KEYSTORE_STORE_PASSWORD")
            val envKeyPass = System.getenv("KEYSTORE_KEY_PASSWORD")
            val envKeyAlias = System.getenv("KEYSTORE_KEY_ALIAS")
            val envStorePath = System.getenv("KEYSTORE_PATH")

            // 3. CHARGEMENT LOCAL (Si le fichier existe)
            // Note: On utilise Properties() tout court, PAS java.util.Properties()
            val keystoreProperties = Properties()
            val keystoreFile = rootProject.file("key.properties")
            
            if (keystoreFile.exists()) {
                // Note: On utilise FileInputStream() tout court
                keystoreProperties.load(FileInputStream(keystoreFile))
            }

            // 4. LOGIQUE DE SELECTION
            if (envStorePass != null && envKeyPass != null && envKeyAlias != null && envStorePath != null) {
                // CI GitHub Actions
                storeFile = file(envStorePath)
                storePassword = envStorePass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            }
            else if (keystoreProperties.getProperty("storePassword") != null) {
                // Local avec key.properties
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // CORRECTION: Retirer cette ligne permet au build d'utiliser l'ID de base.
            // Remettez-la SEULEMENT si vous avez enregistré .debug dans Firebase !
            // applicationIdSuffix = ".debug"
            
            resValue("string", "app_name", "Magic Dev 🛠️")
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("release") {
            // Utilise la config définie plus haut
            signingConfig = signingConfigs.getByName("release")
            
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