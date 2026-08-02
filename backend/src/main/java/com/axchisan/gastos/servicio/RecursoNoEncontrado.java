package com.axchisan.gastos.servicio;

import java.util.UUID;

/**
 * El recurso solicitado no existe, o pertenece a otro usuario.
 *
 * <p>Ambos casos producen la misma respuesta a propósito: si pedir el recurso de otra persona
 * devolviera «prohibido» en lugar de «no encontrado», se podría averiguar qué identificadores
 * existen en el sistema.
 */
public class RecursoNoEncontrado extends RuntimeException {

    public RecursoNoEncontrado(String recurso, UUID id) {
        super("No se encontró " + recurso + " con identificador " + id);
    }

    public RecursoNoEncontrado(String mensaje) {
        super(mensaje);
    }
}
