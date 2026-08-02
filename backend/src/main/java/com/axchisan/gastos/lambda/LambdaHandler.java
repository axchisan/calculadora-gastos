package com.axchisan.gastos.lambda;

import com.amazonaws.serverless.exceptions.ContainerInitializationException;
import com.amazonaws.serverless.proxy.model.HttpApiV2ProxyRequest;
import com.amazonaws.serverless.proxy.model.AwsProxyResponse;
import com.amazonaws.serverless.proxy.spring.SpringBootLambdaContainerHandler;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestStreamHandler;
import com.axchisan.gastos.CalculadoraGastosApplication;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Adaptador entre AWS Lambda y Spring Boot.
 *
 * <p>El contexto de Spring se inicializa en el bloque estático, es decir, durante la fase de
 * inicialización de Lambda. Esto es lo que permite que <b>SnapStart</b> capture el snapshot con
 * la aplicación ya arrancada y reduzca el arranque en frío de varios segundos a unos cientos de
 * milisegundos.
 *
 * <p>Se usa el formato de carga <b>2.0</b> ({@link HttpApiV2ProxyRequest}) porque es el que
 * emiten las Function URL de Lambda.
 *
 * @see <a href="../../../../../../../docs/adr/0002-lambda-spring-boot.md">ADR 0002</a>
 */
public class LambdaHandler implements RequestStreamHandler {

    private static final SpringBootLambdaContainerHandler<HttpApiV2ProxyRequest, AwsProxyResponse> HANDLER;

    static {
        try {
            HANDLER = SpringBootLambdaContainerHandler.getHttpApiV2ProxyHandler(
                    CalculadoraGastosApplication.class);
        } catch (ContainerInitializationException e) {
            // Sin contexto de Spring no hay nada que servir: es preferible fallar en el
            // arranque de Lambda que responder errores en cada petición.
            throw new IllegalStateException("No se pudo inicializar el contexto de Spring", e);
        }
    }

    @Override
    public void handleRequest(InputStream input, OutputStream output, Context context)
            throws IOException {
        HANDLER.proxyStream(input, output, context);
    }
}
