plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.reminderflutter"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.reminderflutter"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        
        // ← ADICIONE esta linha
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        
        // ← ADICIONE estas linhas para desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ← ADICIONE esta dependência para desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}