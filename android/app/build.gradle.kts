plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

fun getDefaultVersion(): Pair<String, Int> {
    val pubspecFile = rootProject.file("../pubspec.yaml")
    if (pubspecFile.exists()) {
        val match = Regex("""version:\s*([0-9\.]+)\+?([0-9]*)""").find(pubspecFile.readText())
        if (match != null) {
            return Pair(
                match.groupValues[1],
                match.groupValues[2].toIntOrNull() ?: 1
            )
        }
    }
    return Pair("2.2.6", 30)
}

val (defaultVersionName, defaultVersionCode) = getDefaultVersion()
val versionNameValue = providers.gradleProperty("versionName").orNull ?: defaultVersionName
val versionCodeValue = providers.gradleProperty("versionCode").orNull?.toIntOrNull() ?: defaultVersionCode

android {
    namespace = "com.syameimarukoa.fs050w_signal_display"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.syameimarukoa.fs050w_signal_display"
        minSdk = 33
        targetSdk = 36
        versionCode = versionCodeValue
        versionName = versionNameValue
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.19.1")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.navigation:navigation-compose:2.10.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
}
