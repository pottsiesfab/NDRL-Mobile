import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(
        FileInputStream(keystorePropertiesFile)
    )
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nostalgiadragleague.ndrl"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nostalgiadragleague.ndrl"
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
    }

    signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

    buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
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

val dartDefines = if (project.hasProperty("dart-defines")) {
    project.property("dart-defines").toString().split(",").associate { entry ->
        val decoded = String(java.util.Base64.getDecoder().decode(entry), Charsets.UTF_8)
        val parts = decoded.split("=", limit = 2)
        parts[0] to (parts.getOrElse(1) { "" })
    }
} else {
    emptyMap()
}

val appEnv = if (dartDefines["APP_ENV"] == "prod") "prod" else "dev"

tasks.matching { it.name.contains("GoogleServices") }.configureEach {
    doFirst {
        val src = file("firebase/$appEnv/google-services.json")
        val dst = file("google-services.json")
        if (src.exists()) {
            src.copyTo(dst, overwrite = true)
            println("NDRL Firebase: Copied $appEnv google-services.json -> app/google-services.json")
        }
    }
}
