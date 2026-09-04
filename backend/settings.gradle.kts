plugins {
    // Deja que Gradle se descargue el JDK que pide el proyecto cuando la máquina no lo tiene.
    // Sin esto, actualizar el Java del sistema rompía la compilación local con un escueto
    // «25.0.4.1» por toda explicación, aunque en integración continua siguiera funcionando
    // porque allí el 21 se instala aparte.
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.10.0"
}

rootProject.name = "calculadora-gastos-backend"
