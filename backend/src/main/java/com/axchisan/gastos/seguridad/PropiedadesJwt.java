package com.axchisan.gastos.seguridad;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * Configuración de los tokens.
 *
 * @param secret             clave de firma HS256; en AWS se inyecta desde SSM Parameter Store
 * @param accessTokenMinutes vigencia del token de acceso
 * @param refreshTokenDays   vigencia del token de refresco
 */
@ConfigurationProperties(prefix = "app.jwt")
public record PropiedadesJwt(String secret, int accessTokenMinutes, int refreshTokenDays) {

    /** Longitud mínima del secreto para firmar con HS256 (256 bits). */
    private static final int LONGITUD_MINIMA_SECRETO = 32;

    public PropiedadesJwt {
        if (secret == null || secret.getBytes(java.nio.charset.StandardCharsets.UTF_8).length
                < LONGITUD_MINIMA_SECRETO) {
            throw new IllegalStateException(
                    "app.jwt.secret debe tener al menos " + LONGITUD_MINIMA_SECRETO
                            + " bytes para firmar con HS256");
        }
        if (accessTokenMinutes <= 0 || refreshTokenDays <= 0) {
            throw new IllegalStateException("Las vigencias de los tokens deben ser positivas");
        }
    }

    public Duration duracionAcceso() {
        return Duration.ofMinutes(accessTokenMinutes);
    }

    public Duration duracionRefresco() {
        return Duration.ofDays(refreshTokenDays);
    }
}
