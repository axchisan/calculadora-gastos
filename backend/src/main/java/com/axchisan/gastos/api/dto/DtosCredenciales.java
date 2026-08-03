package com.axchisan.gastos.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Cambios sobre las credenciales de la cuenta. */
public final class DtosCredenciales {

    private DtosCredenciales() {
    }

    /**
     * Cambio de contraseña.
     *
     * <p>Se exige la actual para que no baste con encontrar una sesión abierta en un
     * dispositivo desatendido para quedarse con la cuenta.
     */
    public record CambiarPasswordRequest(

            @NotBlank(message = "Escribe tu contraseña actual")
            String passwordActual,

            @NotBlank(message = "Escribe la contraseña nueva")
            @Size(min = 8, max = 72, message = "La contraseña debe tener entre 8 y 72 caracteres")
            String passwordNueva) {
    }

    /** Cambio del correo de acceso. */
    public record CambiarEmailRequest(

            @NotBlank(message = "Escribe tu contraseña")
            String password,

            @NotBlank(message = "Escribe el correo nuevo")
            @Email(message = "El correo no tiene un formato válido")
            @Size(max = 255, message = "El correo no puede superar los 255 caracteres")
            String emailNuevo) {
    }

    /** Cambio del nombre visible. */
    public record CambiarNombreRequest(

            @NotBlank(message = "Escribe tu nombre")
            @Size(max = 120, message = "El nombre no puede superar los 120 caracteres")
            String nombre) {
    }

    /**
     * Estado del registro.
     *
     * @param abierto si se admiten cuentas nuevas. La aplicación web lo consulta para decidir
     *                si muestra la opción de crear cuenta o solo la de entrar.
     */
    public record EstadoRegistro(boolean abierto) {
    }
}
