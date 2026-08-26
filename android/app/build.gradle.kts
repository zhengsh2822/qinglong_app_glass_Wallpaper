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
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ABI 由 Flutter 插件根据 --target-platform 自动配置，
        // 构建命令统一传 android-arm64（见根目录构建脚本/说明）。
        // 不要手动设置 splits/ndk.abiFilters，避免与 Flutter 插件冲突。
    }

    buildTypes {
        release {
            // 启用 R8 代码矮化 + 资源压缩，减小 APK 体积、tree-shaking 优化
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
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
