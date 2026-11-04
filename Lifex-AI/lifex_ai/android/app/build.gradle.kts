plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lifex_ai"
    compileSdk = 36
    ndkVersion = "25.1.8937393"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications for Java 8+ APIs on minSdk 24.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // لا تغيّر applicationId — هذا معرّف التطبيق الرسمي على Google Play
        applicationId = "com.lifex_ai"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // TODO: استبدال بتوقيع إنتاجي حقيقي (keystore) قبل النشر على Google Play.
            // مؤقتًا نستخدم مفتاح debug فقط ليتمكن flutter build apk --release من إنتاج APK قابل للتجربة.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Desugaring required by flutter_local_notifications on Android.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
