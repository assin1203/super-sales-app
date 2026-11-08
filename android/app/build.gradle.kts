import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * release 签名凭据来自 android/key.properties + android/app/kqw-release.jks（两者均已被 gitignore）。
 *
 * 缺文件时**直接拒绝 release 构建**（见下方 guard）：静默回落 debug 签名可以编译成功，
 * 但 debug 证书与正式证书不同，发出去的包老用户无法覆盖升级，代价远大于构建失败。
 * 本地只想跑通 release 流程时，用 `flutter build apk --debug` 或先配好自己的 keystore。
 *
 * 注意：正式对外发布必须用这个 keystore 签名，换签名会导致老用户无法覆盖安装。
 */
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

// 只拦 release 任务：debug/profile 构建不要求签名文件，新克隆的仓库仍能直接 flutter run
if (!keystorePropertiesFile.exists() &&
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
) {
    throw GradleException(
        "缺少 android/key.properties：release 构建必须使用正式签名。\n" +
            "请从备份恢复 key.properties 与 app/kqw-release.jks 后再发版；" +
            "仅调试请改用 flutter build apk --debug / flutter run。"
    )
}

android {
    namespace = "com.kqw.kqw_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kqw.kqw_app"
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
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 有 key.properties 用正式签名，否则回落 debug（仅本地调试用，不可对外发版）
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
