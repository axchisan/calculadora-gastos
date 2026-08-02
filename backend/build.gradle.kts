plugins {
    java
    id("org.springframework.boot") version "3.5.4"
    id("io.spring.dependency-management") version "1.1.7"
    id("com.gradleup.shadow") version "8.3.6"
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

    // --- Documentación de la API ---
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.6")

    // --- Pruebas ---
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

dependencyManagement {
    imports {
        mavenBom("org.testcontainers:testcontainers-bom:1.20.6")
    }
}

tasks.withType<JavaCompile> {
    options.encoding = "UTF-8"
    options.compilerArgs.add("-parameters")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// El artefacto que se despliega en Lambda es el JAR sombreado, no el de Spring Boot:
// Lambda necesita las clases en la raíz del ZIP, no anidadas en BOOT-INF.
tasks.shadowJar {
    archiveClassifier = "lambda"
    mergeServiceFiles()
    // Firmas de dependencias que rompen la validación del JAR resultante.
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")
}

tasks.named("build") {
    dependsOn(tasks.shadowJar)
}

// El JAR ejecutable de Spring Boot se sigue generando para ejecutar en local.
tasks.bootJar {
    archiveClassifier = "boot"
}
