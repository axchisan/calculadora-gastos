import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Datos del almacén de claves con el que se firman las compilaciones de publicación. El archivo
// no está en el repositorio porque contiene contraseñas; ver docs/APLICACIONES.md para crearlo.
// Si no existe, la compilación sigue funcionando con la clave de depuración, de modo que
// `flutter build apk --release` no falla en una copia recién clonada del repositorio.
val propiedadesFirma = Properties()
val archivoFirma = rootProject.file("key.properties")
if (archivoFirma.exists()) {
    archivoFirma.inputStream().use { propiedadesFirma.load(it) }
}
val hayFirmaPropia = propiedadesFirma.containsKey("storeFile")

android {
    namespace = "com.axchisan.calculadora_gastos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.axchisan.calculadora_gastos"
        // El almacén seguro guarda los tokens en el Keystore con respaldo de hardware, que está
        // disponible desde Android 6.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // La interfaz solo está en español; incluir el resto de idiomas de las bibliotecas de
        // Android engorda el paquete sin aportar nada.
        resourceConfigurations += listOf("es")
    }

    signingConfigs {
        if (hayFirmaPropia) {
            create("publicacion") {
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
                storeFile = file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayFirmaPropia) {
                signingConfigs.getByName("publicacion")
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
