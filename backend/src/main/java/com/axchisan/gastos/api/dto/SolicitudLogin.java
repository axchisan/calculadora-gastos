package com.axchisan.gastos.api.dto;

import jakarta.validation.constraints.NotBlank;

/** Credenciales de inicio de sesión. */
public record SolicitudLogin(

        @NotBlank(message = "El correo es obligatorio")
        String email,

        @NotBlank(message = "La contraseña es obligatoria")
        String password) {
}
