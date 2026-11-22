package com.axchisan.gastos.servicio;

import java.util.UUID;

/**
 * El identificador que propuso la app al crear un registro ya lo usa un registro de otro usuario.
 *
 * <p>La app genera el identificador cuando apunta algo sin conexión, para que reenviarlo al volver
 * la red no lo duplique. Con UUID v7 una colisión real es prácticamente imposible, así que esto
 * solo ocurre ante una petición manipulada.
 */
public class IdentificadorEnUso extends RuntimeException {

    public IdentificadorEnUso(UUID id) {
        super("El identificador " + id + " ya está en uso");
    }
}
