package com.axchisan.gastos.api.dto;

import jakarta.validation.constraints.NotBlank;

/** Token de refresco para renovar la sesión o cerrarla. */
public record SolicitudRefresco(

        @NotBlank(message = "El token de refresco es obligatorio")
        String refreshToken) {
}
