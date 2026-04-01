import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

android {
    namespace = "com.travelbox.peru.travelbox_peru_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.travelbox.peru.travelbox_peru_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = System.getenv("GOOGLE_MAPS_API_KEY") ?: project.findProperty("GOOGLE_MAPS_API_KEY") as String? ?: ""
    }

    buildTypes {
        release {
            val releaseStoreFile = signingProperties.getProperty("storeFile")
            val releaseStorePassword = signingProperties.getProperty("storePassword")
            val releaseKeyAlias = signingProperties.getProperty("keyAlias")
            val releaseKeyPassword = signingProperties.getProperty("keyPassword")

            if (
                releaseStoreFile.isNullOrBlank() ||
                releaseStorePassword.isNullOrBlank() ||
                releaseKeyAlias.isNullOrBlank() ||
                releaseKeyPassword.isNullOrBlank()
            ) {
                throw GradleException(
                    "Missing Android release signing configuration. Provide android/key.properties.",
                )
            }

            signingConfig = signingConfigs.create("release").apply {
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/DEPENDENCIES"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
