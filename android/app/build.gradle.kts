import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Боевой ключ подписи живёт вне репозитория: android/key.properties
// (файл в .gitignore, шаблон — key.properties.example).
//
// Без него сборка не падает, а подписывается debug-ключом: иначе
// `flutter run --release` не запустился бы ни у кого, кроме держателя ключа.
// Такой APK ставится на устройство, но в Play его не принять.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "uz.millwater.crm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "uz.millwater.crm"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeystore) "release" else "debug"
            )
            // R8 включён: без него APK крупнее, а Kotlin/Java-часть плагинов
            // уходит в релиз неминифицированной.
            //
            // ВАЖНО. Ошибки R8 проявляются не при компиляции, а в рантайме и
            // только в release-сборке — тесты и отладка их не поймают. После
            // каждого изменения зависимостей релиз надо ставить на устройство
            // и проходить вход и завершение доставки: это два места, где
            // рефлексия реальна (Tink в хранилище токенов, multipart с фото).
            //
            // Правила лежат в proguard-rules.pro. Плагины, которым нужны свои
            // keep'ы, приносят их сами через consumerProguardFiles —
            // так делает, например, sentry_flutter.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
