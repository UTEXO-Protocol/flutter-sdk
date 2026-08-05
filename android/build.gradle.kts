import groovy.json.JsonSlurper

val releaseBaselineFile = file("../tool/release_baseline.json")
require(releaseBaselineFile.isFile) {
    "Missing release baseline: ${releaseBaselineFile.absolutePath}"
}
val releaseBaseline = JsonSlurper().parse(releaseBaselineFile) as Map<*, *>
val rlnBaseline = releaseBaseline["rln"] as Map<*, *>
val rlnAndroidBaseline = rlnBaseline["android"] as Map<*, *>
val rlnAndroidCoordinate = rlnAndroidBaseline["mavenCoordinate"] as String
val buildRequirements = releaseBaseline["buildRequirements"] as Map<*, *>
val androidBuildRequirements = buildRequirements["android"] as Map<*, *>
val baselineCompileSdk =
    (androidBuildRequirements["compileSdk"] as Number).toInt()
val baselineMinSdk =
    (androidBuildRequirements["minSdk"] as Number).toInt()
val baselineJavaVersion =
    (androidBuildRequirements["javaLanguageVersion"] as Number).toInt()

group = "com.utexo.rgb_sdk_flutter"
version = "0.1.0"

buildscript {
    val baseline =
        groovy.json.JsonSlurper().parse(file("../tool/release_baseline.json")) as Map<*, *>
    val requirements = baseline["buildRequirements"] as Map<*, *>
    val androidRequirements = requirements["android"] as Map<*, *>
    val kotlinVersion = androidRequirements["kotlinVersion"] as String
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.utexo.rgb_sdk_flutter"

    compileSdk = baselineCompileSdk

    compileOptions {
        sourceCompatibility = JavaVersion.toVersion(baselineJavaVersion)
        targetCompatibility = JavaVersion.toVersion(baselineJavaVersion)
    }

    kotlinOptions {
        jvmTarget = JavaVersion.toVersion(baselineJavaVersion).toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = baselineMinSdk
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    implementation(rlnAndroidCoordinate)
    implementation("net.java.dev.jna:jna:5.17.0@aar")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
}
