plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun getPubspecVersion(): Pair<String, Int> {
    val pubspecFile = rootProject.file("../pubspec.yaml")
    if (pubspecFile.exists()) {
        val content = pubspecFile.readText()
        val match = Regex("""version:\s*([0-9\.]+)\+?([0-9]*)""").find(content)
        if (match != null) {
            val name = match.groupValues[1]
            val code = match.groupValues[2].toIntOrNull() ?: 1
            return Pair(name, code)
        }
    }
    return Pair("2.2.6", 30)
}

val (pubspecVersionName, pubspecVersionCode) = getPubspecVersion()

android {
    namespace = "com.syameimarukoa.fs050w_signal_display"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.syameimarukoa.fs050w_signal_display"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        versionCode = if (flutter.versionCode != null && flutter.versionCode != 1) flutter.versionCode else pubspecVersionCode
        versionName = if (flutter.versionName != null && flutter.versionName != "1.0") flutter.versionName else pubspecVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin", "src/main/java")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
