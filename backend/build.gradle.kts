plugins {
    java
    id("org.springframework.boot") version "3.5.4"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.axchisan"
version = "0.1.0"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

extra["awsLambdaContainerVersion"] = "2.1.3"
extra["jjwtVersion"] = "0.12.6"
extra["springCloudAwsVersion"] = "3.3.0"

dependencyManagement {
    imports {
        mavenBom("io.awspring.cloud:spring-cloud-aws-dependencies:${property("springCloudAwsVersion")}")
    }
}

dependencies {
    // --- Spring Boot ---
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-validation")

    // --- Base de datos ---
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-database-postgresql")
    runtimeOnly("org.postgresql:postgresql")

    // Identificadores UUID v7: ordenables por tiempo, lo que preserva la localidad en los
    // índices B-tree frente a los v4 aleatorios.
    implementation("com.fasterxml.uuid:java-uuid-generator:5.1.0")

    // --- Autenticación JWT ---
    implementation("io.jsonwebtoken:jjwt-api:${property("jjwtVersion")}")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:${property("jjwtVersion")}")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:${property("jjwtVersion")}")

    // --- AWS Lambda ---
    // Adapta los eventos de Lambda al DispatcherServlet de Spring.
    implementation("com.amazonaws.serverless:aws-serverless-java-container-springboot3:${property("awsLambdaContainerVersion")}")
    implementation("com.amazonaws:aws-lambda-java-core:1.2.3")
    implementation("com.amazonaws:aws-lambda-java-events:3.14.0")
    // CRaC: hooks para reinicializar recursos tras restaurar el snapshot de SnapStart.
    implementation("org.crac:crac:1.5.0")

    // Lee la configuración sensible desde SSM Parameter Store al arrancar, de modo que las
    // credenciales no viajan en el código, ni en variables de entorno, ni en el estado de
    // Terraform.
    implementation("io.awspring.cloud:spring-cloud-aws-starter-parameter-store")

    // --- Documentación de la API ---
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.6")

    // --- Pruebas ---
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<JavaCompile> {
    options.encoding = "UTF-8"
    options.compilerArgs.add("-parameters")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// Paquete de despliegue para Lambda.
//
// Usa el formato nativo del runtime de Java: las clases de la aplicación en la raíz y las
// dependencias como JAR independientes dentro de "lib/", que Lambda añade al classpath por su
// cuenta.
//
// No se usa un JAR sombreado (shadow/uber-jar) porque fusionar todas las dependencias en un
// único JAR sobrescribe los metadatos de Spring: los descriptores de autoconfiguración bajo
// META-INF existen con el mismo nombre en varios artefactos, y al perderse parte de ellos
// Spring Data deja de registrar los repositorios. Manteniendo las dependencias separadas, el
// classpath es idéntico al de una ejecución normal.
//
// Tampoco sirve el JAR ejecutable de Spring Boot: anida todo bajo "BOOT-INF/", que el runtime
// de Lambda no sabe leer.
tasks.register<Zip>("paqueteLambda") {
    group = "distribution"
    description = "Empaqueta la aplicación en el formato que espera AWS Lambda"

    archiveFileName = "backend-lambda.zip"
    destinationDirectory = layout.buildDirectory.dir("distributions")

    from(sourceSets.main.get().output)
    into("lib") {
        from(configurations.runtimeClasspath)
    }
}

tasks.named("build") {
    dependsOn("paqueteLambda")
}

// El JAR ejecutable de Spring Boot se sigue generando para ejecutar en local.
tasks.bootJar {
    archiveClassifier = "boot"
}
