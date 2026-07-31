plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.qlapp.qinglong_app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.qlapp.qinglong_app"
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    splits {
        abi {
            // Debug 模式禁用 split，确保 flutter run 能正常工作
            // Release 模式启用 split，生成精简的 arm64 APK
            isEnable = !gradle.startParameter.taskNames.any { it.contains("Debug") }
            reset()
            include("arm64-v8a")
            isUniversalApk = false
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    // 金标联盟公平调度：ProcessLifecycleOwner 用于监听应用前后台切换
    // 当应用进入后台时，Flutter 端可暂停 Timer.periodic 轮询，避免无意义占用 CPU
    implementation("androidx.lifecycle:lifecycle-process:2.6.2")
}

flutter {
    source = "../.."
}

// 构建完成后复制 arm64-v8a APK 为 app-release.apk，让 Flutter 工具能识别
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val src = layout.buildDirectory.file("outputs/apk/release/app-arm64-v8a-release.apk").get().asFile
        val dst1 = layout.buildDirectory.file("outputs/apk/release/app-release.apk").get().asFile
        val dst2 = layout.buildDirectory.file("outputs/flutter-apk/app-release.apk").get().asFile
        if (src.exists()) {
            src.copyTo(dst1, overwrite = true)
            dst2.parentFile.mkdirs()
            src.copyTo(dst2, overwrite = true)
            println("Copied ${src.name} to ${dst1.name} and ${dst2.name} for Flutter tool compatibility")
        }
    }
}
