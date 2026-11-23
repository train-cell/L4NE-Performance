plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.l4ne.training"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.l4ne.training"
        minSdk = 28
        targetSdk = 35
        versionCode = 2
        versionName = "1.1.0"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.10.0")
    implementation("androidx.compose.material3:material3:1.3.1")
    implementation("androidx.health.connect:connect-client:1.1.0-alpha11")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")
}
