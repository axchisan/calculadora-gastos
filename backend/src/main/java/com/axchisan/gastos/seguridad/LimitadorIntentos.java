package com.axchisan.gastos.seguridad;

import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Frena los intentos de inicio de sesión por fuerza bruta.
 *
 * <p><b>Limitación conocida:</b> el conteo vive en memoria, así que cada instancia de Lambda
 * lleva la suya. Con concurrencia alta, un atacante dispondría de tantos intentos como
 * instancias activas. Es una barrera contra ataques triviales, no una defensa completa; si el
 * uso creciera hasta necesitarlo, habría que llevar el contador a la base de datos.
 */
@Component
public class LimitadorIntentos {

    private static final int MAX_INTENTOS = 5;
    private static final Duration VENTANA = Duration.ofMinutes(15);
    /** Por encima de este número de claves, se purgan las entradas vencidas. */
    private static final int UMBRAL_LIMPIEZA = 1_000;

    private final Map<String, Intentos> porClave = new ConcurrentHashMap<>();

    /**
     * Verifica si la clave puede seguir intentando.
     *
     * @throws ExcepcionesAutenticacion.DemasiadosIntentos si se agotaron los intentos
     */
    public void verificar(String clave) {
        Intentos intentos = porClave.get(clave);
        if (intentos == null || intentos.venció()) {
            return;
        }
        if (intentos.contador.get() >= MAX_INTENTOS) {
            throw new ExcepcionesAutenticacion.DemasiadosIntentos(intentos.segundosRestantes());
        }
    }

    /** Registra un intento fallido. */
    public void registrarFallo(String clave) {
        if (porClave.size() > UMBRAL_LIMPIEZA) {
            porClave.values().removeIf(Intentos::venció);
        }
        porClave.compute(clave, (k, actual) ->
                actual == null || actual.venció() ? new Intentos() : actual.incrementar());
    }

    /** Limpia el contador tras un inicio de sesión correcto. */
    public void registrarExito(String clave) {
        porClave.remove(clave);
    }

    private static final class Intentos {
        private final AtomicInteger contador = new AtomicInteger(1);
        private final Instant expira = Instant.now().plus(VENTANA);

        boolean venció() {
            return Instant.now().isAfter(expira);
        }

        long segundosRestantes() {
            return Math.max(0, Duration.between(Instant.now(), expira).toSeconds());
        }

        Intentos incrementar() {
            contador.incrementAndGet();
            return this;
        }
    }
}
