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

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task ->
        task.path.contains("Release", ignoreCase = true)
    }
    if (releaseRequested && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties; release builds must use the production signing key."
        )
    }
}

android {
    namespace = "com.sadat.jamaattime"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.sadat.jamaattime"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "appMode"

    productFlavors {
        create("prayerOnly") {
            dimension = "appMode"
            applicationId = "com.sadat.jamaattime"
            isDefault = true
        }
        create("familySafetyFull") {
            dimension = "appMode"
            applicationId = "com.sadat.jamaattime.safety"
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

androidComponents {
    beforeVariants(
        selector()
            .withBuildType("release")
            .withFlavor("appMode" to "familySafetyFull")
    ) { variantBuilder ->
        variantBuilder.enable = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.work:work-runtime:2.9.1")
    implementation("androidx.core:core-ktx:1.13.1")
    testImplementation("junit:junit:4.13.2")
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        jvmTarget = "11"
    }
}

val copyPrayerOnlyReleaseForFlutter by tasks.registering(Copy::class) {
    dependsOn("assemblePrayerOnlyRelease")
    from(layout.buildDirectory.dir("outputs/apk/prayerOnly/release")) {
        include("app-prayerOnly-release.apk")
        include("app-prayerOnly-*-release.apk")
    }
    into(layout.buildDirectory.dir("outputs/flutter-apk"))
    rename { fileName ->
        fileName
            .replace("app-prayerOnly-release.apk", "app-release.apk")
            .replace("app-prayerOnly-", "app-")
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(copyPrayerOnlyReleaseForFlutter)
}
