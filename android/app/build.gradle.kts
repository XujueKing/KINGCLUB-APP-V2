plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lingmei.kingclub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // The ARM64 preview builder supplies a freshly compiled, reviewed native
    // library. Ordinary builds do not silently pick up stale local binaries.
    val novoRudpJni = System.getenv("KINGCLUB_NOVORUDP_JNI_DIR")
    if (!novoRudpJni.isNullOrBlank()) {
        require(file("$novoRudpJni/arm64-v8a/libkingclub_novorudp.so").isFile) {
            "NovoRUDP native library is missing; run scripts/build-novorudp-android.ps1"
        }
        sourceSets.getByName("main").jniLibs.srcDir(novoRudpJni)
    }

    flavorDimensions += "distribution"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.lingmei.kingclub"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    productFlavors {
        create("preview") {
            dimension = "distribution"
            // Vendor push registration uses the same identity as the published app.
            // Keep the build flavor, but do not change the installed package name.
            versionNameSuffix = "-preview"
        }
        create("filetest") {
            dimension = "distribution"
            applicationIdSuffix = ".filetest"
            versionNameSuffix = "-filetest"
        }
        create("calltest") {
            dimension = "distribution"
            applicationIdSuffix = ".calltest"
            versionNameSuffix = "-calltest"
        }
    }

    buildTypes {
        release {
            // Intentionally unsigned until the production signing work package is approved.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Keep aligned with video_player_android's ExoPlayer version.
dependencies {
    implementation("androidx.media3:media3-transformer:1.9.2")
    implementation("androidx.media3:media3-effect:1.9.2")
}
