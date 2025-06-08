plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.email_application"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion không cần thiết cho trường hợp này, bạn có thể giữ hoặc xóa
    ndkVersion = "27.0.12077973"

    compileOptions {
        // BẬT CORE LIBRARY DESUGARING
        isCoreLibraryDesugaringEnabled = true
        // Giữ nguyên phiên bản Java mà project của bạn đang dùng
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.email_application"
        // Thay đổi minSdkVersion thành 23 hoặc cao hơn nếu cần
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    // THAY ĐỔI: CẬP NHẬT PHIÊN BẢN THEO YÊU CẦU CỦA LỖI
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
