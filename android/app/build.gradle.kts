import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// BẮT ĐẦU: ĐOẠN MÃ ĐỌC key.properties (Kotlin DSL)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// KẾT THÚC: ĐOẠN MÃ ĐỌC key.properties

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
        // THAY ĐỔI DÒNG NÀY TỪ 23 THÀNH 26
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // BẮT ĐẦU: CẤU HÌNH KÝ ỨNG DỤNG (Kotlin DSL)
    signingConfigs {
        create("release") { // Sử dụng create("release") thay vì getByName("release")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }
    // KẾT THÚC: CẤU HÌNH KÝ ỨNG DỤNG

    buildTypes {
        getByName("release") { // Sử dụng getByName("release")
            // Thay đổi signingConfig từ "debug" sang "release"
            signingConfig = signingConfigs.getByName("release")

            // Rất khuyến khích để tối ưu hóa kích thước và hiệu suất
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false // Đảm bảo đây không phải là bản debug
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