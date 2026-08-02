package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.seguridad.Sesion;

/**
 * Tokens entregados al cliente tras autenticarse.
 *
 * @param accessToken  JWT que acompaña cada petición en la cabecera Authorization
 * @param refreshToken token para renovar el acceso; el cliente debe guardarlo en el
 *                     almacenamiento seguro de la plataforma
 * @param expiraEn     segundos de vigencia del token de acceso
 * @param usuario      datos del usuario autenticado
 */
public record RespuestaSesion(String accessToken, String refreshToken, long expiraEn,
                              UsuarioDto usuario) {

    public static RespuestaSesion de(Sesion sesion) {
        return new RespuestaSesion(
                sesion.accessToken(),
                sesion.refreshToken(),
                sesion.expiraEnSegundos(),
                UsuarioDto.de(sesion.usuario()));
    }
}
