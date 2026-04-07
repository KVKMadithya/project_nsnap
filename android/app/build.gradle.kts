import java.util.Properties // <--- ADD THIS IMPORT AT THE VERY TOP

// --- LOGIC TO READ LOCAL.PROPERTIES ---
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
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

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.nsnap"

        // ARCore strictly requires 24!
        minSdk = 24

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --- INJECT THE API KEY INTO ANDROID RESOURCES ---
        // This takes the key from local.properties and creates a string resource 
        // that the AndroidManifest.xml can see as "@string/GOOGLE_MAPS_API_KEY"
        val mapsKey = localProperties.getProperty("GOOGLE_MAPS_API_KEY") ?: ""
        resValue("string", "GOOGLE_MAPS_API_KEY", mapsKey)
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