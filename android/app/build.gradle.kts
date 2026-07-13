plugins {
    id("com.android.application")
<<<<<<< HEAD
=======
    id("kotlin-android")
>>>>>>> c4e3bdba46f3774bf6c626a037b8307d68d12f94
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
<<<<<<< HEAD
    namespace = "com.quickmed.quickmed"
=======
    namespace = "com.example.quickmed"
>>>>>>> c4e3bdba46f3774bf6c626a037b8307d68d12f94
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
<<<<<<< HEAD
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
=======
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
>>>>>>> c4e3bdba46f3774bf6c626a037b8307d68d12f94
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
<<<<<<< HEAD
        applicationId = "com.quickmed.quickmed"
=======
        applicationId = "com.example.quickmed"
>>>>>>> c4e3bdba46f3774bf6c626a037b8307d68d12f94
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

<<<<<<< HEAD
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

=======
>>>>>>> c4e3bdba46f3774bf6c626a037b8307d68d12f94
flutter {
    source = "../.."
}
