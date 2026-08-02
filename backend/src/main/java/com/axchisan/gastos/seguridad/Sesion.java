package com.axchisan.gastos.seguridad;

import com.axchisan.gastos.dominio.Usuario;

/**
 * Par de tokens emitidos tras autenticarse.
 *
 * @param accessToken       JWT de vida corta que acompaña cada petición
 * @param refreshToken      token opaco para renovar el acceso; solo se entrega en claro aquí
 * @param expiraEnSegundos  vigencia del token de acceso
 * @param usuario           usuario autenticado
 */
public record Sesion(String accessToken, String refreshToken, long expiraEnSegundos,
                     Usuario usuario) {
}
