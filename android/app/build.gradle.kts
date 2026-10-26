import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = System.getenv("LIANJI_KEY_PROPERTIES")?.let { File(it) }
val signingProperties = Properties()
if (signingPropertiesFile?.exists() == true) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}

android {
    namespace = "app.lianji.training"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable production identity; QA installs use a separate application ID.
        applicationId = "app.lianji.training"
        if (System.getenv("LIANJI_TEST_BUILD") == "1") {
            val suffix = System.getenv("LIANJI_QA_SUFFIX") ?: ".qa"
            require(suffix == ".qa" || suffix == ".qa.design") { "Unknown QA identity" }
            applicationIdSuffix = suffix
        }
        manifestPlaceholders["appLabel"] = if (System.getenv("LIANJI_QA_SUFFIX") == ".qa.design") "练迹设计验收" else if (System.getenv("LIANJI_TEST_BUILD") == "1") "练迹验证" else "练迹"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingPropertiesFile?.exists() == true) {
            create("lianjiRelease") {
                storeFile = File(signingPropertiesFile.parentFile, signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Standalone performance probes must preserve the isolated QA identity
        // and its existing certificate, just like debug integration fixtures.
        maybeCreate("profile").apply {
            if (System.getenv("LIANJI_TEST_BUILD") == "1" && signingPropertiesFile?.exists() == true) {
                signingConfig = signingConfigs.findByName("lianjiRelease")
            }
        }
        debug {
            // QA variants share the approved certificate to preserve their
            // isolated data when switching between device tests and release QA.
            if (System.getenv("LIANJI_TEST_BUILD") == "1" && signingPropertiesFile?.exists() == true) {
                signingConfig = signingConfigs.findByName("lianjiRelease")
            }
        }
        release {
            // Missing release credentials intentionally produce no debug fallback.
            signingConfig = signingConfigs.findByName("lianjiRelease")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
