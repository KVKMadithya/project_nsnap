import java.util.Properties

// --- LOGIC TO READ LOCAL.PROPERTIES ---
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

plugins {
    id("com.android.application")
    // Use the explicit ID for Kotlin that matches your settings.gradle.kts
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.nsnap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "com.example.nsnap"

        // ARCore strictly requires 24!
        minSdk = 24

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --- INJECT THE API KEY INTO ANDROID RESOURCES ---
        val mapsKey = localProperties.getProperty("GOOGLE_MAPS_API_KEY") ?: ""
        resValue("string", "GOOGLE_MAPS_API_KEY", mapsKey)
    }

    buildTypes {
        release {
            // Using the debug signing for now so you can test on your phone easily
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}