package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.Usuario;

import java.util.UUID;

/** Datos públicos del usuario. Nunca incluye el hash de la contraseña. */
public record UsuarioDto(UUID id, String email, String nombre, String moneda, String zonaHoraria) {

    public static UsuarioDto de(Usuario usuario) {
        return new UsuarioDto(
                usuario.getId(),
                usuario.getEmail(),
                usuario.getNombre(),
                usuario.getMoneda(),
                usuario.getZonaHoraria());
    }
}
