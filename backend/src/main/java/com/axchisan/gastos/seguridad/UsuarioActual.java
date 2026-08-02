package com.axchisan.gastos.seguridad;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;
import java.util.UUID;

/**
 * Acceso al usuario autenticado en la petición en curso.
 *
 * <p>Es la <b>única</b> fuente admitida del identificador de usuario en la capa de servicio.
 * Tomarlo de un parámetro de la petición permitiría acceder a datos ajenos.
 */
public final class UsuarioActual {

    private UsuarioActual() {
    }

    /** Identificador del usuario autenticado. */
    public static UUID id() {
        return buscarId().orElseThrow(
                () -> new IllegalStateException("No hay ningún usuario autenticado"));
    }

    /** Identificador del usuario autenticado, si lo hay. */
    public static Optional<UUID> buscarId() {
        Authentication autenticacion = SecurityContextHolder.getContext().getAuthentication();
        if (autenticacion == null || !autenticacion.isAuthenticated()) {
            return Optional.empty();
        }
        return autenticacion.getPrincipal() instanceof UUID id ? Optional.of(id) : Optional.empty();
    }
}
