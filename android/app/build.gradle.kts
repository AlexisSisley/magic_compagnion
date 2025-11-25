plugins {
    id("com.android.application")
    id("kotlin-android")
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
        applicationId = "com.example.magic_companion"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Magic Companion")
    }

    signingConfigs {
        create("release") {
            // --- LOGIQUE DÉPLACÉE ICI POUR ÉVITER L'ERREUR DE SCOPE ---
            
            // 1. Récupération des variables d'environnement (CI GitHub)
            val envStorePass = System.getenv("KEYSTORE_STORE_PASSWORD")
            val envKeyPass = System.getenv("KEYSTORE_KEY_PASSWORD")
            val envKeyAlias = System.getenv("KEYSTORE_KEY_ALIAS")
            val envStorePath = System.getenv("KEYSTORE_PATH")

            // 2. Tentative de chargement local (key.properties)
            val keystoreProperties = java.util.Properties()
            val keystoreFile = rootProject.file("key.properties")
            if (keystoreFile.exists()) {
                keystoreProperties.load(java.io.FileInputStream(keystoreFile))
            }

            // 3. Application de la configuration
            if (envStorePass != null && envKeyPass != null && envKeyAlias != null && envStorePath != null) {
                // Cas CI / GitHub Actions
                storeFile = file(envStorePath)
                storePassword = envStorePass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            }
            else if (keystoreProperties.getProperty("storePassword") != null) {
                // Cas Développement Local (si key.properties existe)
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
            resValue("string", "app_name", "Magic Dev 🛠️")
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("release") {
            // Utilise la config "release" définie juste au-dessus
            signingConfig = signingConfigs.getByName("release")
            
            // Optimisations pour la production
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