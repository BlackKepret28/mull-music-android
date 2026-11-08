plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mulya.mullmusic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mulya.mullmusic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Cuma arm64 dulu biar APK kecil (Infinix Note 30 = arm64-v8a).
        // Waktu `flutter build apk --split-per-abi`, Flutter pakai splits sendiri,
        // jadi abiFilters dimatikan supaya nggak bentrok.
        // Flutter selalu mengirim properti ini (nilai "false" kalau tanpa --split-per-abi), jadi cek nilainya.
        if (project.findProperty("split-per-abi")?.toString() != "true") {
            ndk { abiFilters += listOf("arm64-v8a") }
        }
    }

    // youtubedl-android menjalankan python/ffmpeg/qjs dari nativeLibraryDir,
    // jadi file .so harus diekstrak ke disk (bukan dibaca langsung dari APK).
    packaging {
        jniLibs {
            useLegacyPackaging = true
            // abiFilters di atas nggak cukup: AAR youtubedl-android tetap menyelipkan semua ABI
            // (dicek 8 Nov, APK 215 MB isi armeabi-v7a/x86_64). Buang di tahap packaging.
            if (project.findProperty("split-per-abi")?.toString() != "true") {
                excludes += listOf("lib/armeabi-v7a/**", "lib/x86/**", "lib/x86_64/**")
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

dependencies {
    // yt-dlp + Python + QuickJS (library) dan ffmpeg untuk Android, dirawat tim Seal. GPL-3.0.
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
}
