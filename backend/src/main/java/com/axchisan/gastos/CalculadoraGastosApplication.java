package com.axchisan.gastos;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Punto de entrada de la aplicación.
 *
 * <p>En local arranca como una aplicación Spring Boot convencional. En AWS, el arranque lo
 * controla {@link com.axchisan.gastos.lambda.LambdaHandler}, que reutiliza este mismo contexto.
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class CalculadoraGastosApplication {

    public static void main(String[] args) {
        SpringApplication.run(CalculadoraGastosApplication.class, args);
    }
}
