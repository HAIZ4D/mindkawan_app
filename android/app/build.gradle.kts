plugins {
    id("com.android.application")
    // Prefer one of these:
    // kotlin("android")                    // ✅ works with Kotlin DSL
    id("org.jetbrains.kotlin.android")      // ✅ explicit plugin id
    // id("kotlin-android")                 // ⚠ only works if aliased in settings.gradle.kts
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mindkawanv2_app"

    // Let Flutter manage these, that’s fine.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.mindkawanv2_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true   // <-- required
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
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
    // REQUIRED for core library desugaring (fixes the AAR metadata error)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
