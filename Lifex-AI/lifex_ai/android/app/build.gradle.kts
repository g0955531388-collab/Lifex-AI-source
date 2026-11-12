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
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
