package com.axchisan.gastos.seguridad;

import com.axchisan.gastos.dominio.Usuario;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

/** Emite y valida los tokens de acceso, y genera los de refresco. */
@Service
public class ServicioTokens {

    private static final Logger log = LoggerFactory.getLogger(ServicioTokens.class);

    /** 32 bytes de entropía: suficiente para que un token de refresco no sea adivinable. */
    private static final int BYTES_REFRESH_TOKEN = 32;

    private final SecretKey clave;
    private final PropiedadesJwt propiedades;
    private final SecureRandom aleatorio = new SecureRandom();

    public ServicioTokens(PropiedadesJwt propiedades) {
        this.propiedades = propiedades;
        this.clave = Keys.hmacShaKeyFor(propiedades.secret().getBytes(StandardCharsets.UTF_8));
    }

    /** Emite un token de acceso para el usuario. */
    public String emitirAccessToken(Usuario usuario) {
        Instant ahora = Instant.now();
        return Jwts.builder()
                .subject(usuario.getId().toString())
                .claim("email", usuario.getEmail())
                .claim("nombre", usuario.getNombre())
                .issuedAt(Date.from(ahora))
                .expiration(Date.from(ahora.plus(propiedades.duracionAcceso())))
                .signWith(clave)
                .compact();
    }

    /**
     * Extrae el identificador del usuario si el token es válido.
     *
     * <p>Devuelve vacío ante cualquier problema — firma inválida, token caducado o alterado — sin
     * distinguir la causa hacia el exterior.
     */
    public Optional<UUID> validarAccessToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(clave)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return Optional.of(UUID.fromString(claims.getSubject()));
        } catch (JwtException | IllegalArgumentException e) {
            log.debug("Token de acceso rechazado: {}", e.getMessage());
            return Optional.empty();
        }
    }

    /** Genera un token de refresco opaco, en Base64 sin relleno. */
    public String generarRefreshToken() {
        byte[] bytes = new byte[BYTES_REFRESH_TOKEN];
        aleatorio.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /**
     * Calcula el hash SHA-256 que se persiste en lugar del token.
     *
     * <p>El token de refresco tiene 256 bits de entropía aleatoria, así que no hace falta una
     * función de derivación lenta como BCrypt: no es adivinable por fuerza bruta.
     */
    public String hashear(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 debería estar siempre disponible", e);
        }
    }

    public PropiedadesJwt propiedades() {
        return propiedades;
    }
}
