plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "app.paylog.sms"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    defaultConfig { applicationId = "app.paylog.sms"; minSdk = 26; targetSdk = 36; versionCode = 4; versionName = "1.0.2" }
    signingConfigs {
        val path = providers.environmentVariable("PAYLOG_RELEASE_STORE_FILE").orNull
        if (path != null) {
            create("production") {
                storeFile = file(path)
                storePassword = providers.environmentVariable("PAYLOG_RELEASE_STORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("PAYLOG_RELEASE_KEY_ALIAS").getOrElse("paylog-release")
                keyPassword = providers.environmentVariable("PAYLOG_RELEASE_KEY_PASSWORD").get()
            }
        }
    }
    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        getByName("release") {
            isDebuggable = false
            signingConfig = signingConfigs.findByName("production")
        }
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation("androidx.work:work-runtime-ktx:2.10.1")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
