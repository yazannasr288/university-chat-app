plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.alwatanyachat"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.alwatanyachat"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseStoreFile =
        (project.findProperty("RELEASE_STORE_FILE") as String?) ?: System.getenv("RELEASE_STORE_FILE")
    val releaseStorePassword =
        (project.findProperty("RELEASE_STORE_PASSWORD") as String?) ?: System.getenv("RELEASE_STORE_PASSWORD")
    val releaseKeyAlias =
        (project.findProperty("RELEASE_KEY_ALIAS") as String?) ?: System.getenv("RELEASE_KEY_ALIAS")
    val releaseKeyPassword =
        (project.findProperty("RELEASE_KEY_PASSWORD") as String?) ?: System.getenv("RELEASE_KEY_PASSWORD")

    val hasReleaseSigning = listOf(
        releaseStoreFile,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword
    ).all { !it.isNullOrBlank() }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.webkit:webkit:1.6.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}