package com.axchisan.gastos.seguridad;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Traduce el token {@code Authorization: Bearer} en una autenticación de Spring Security.
 *
 * <p>El identificador del usuario se toma <b>siempre</b> del token, nunca de un parámetro de la
 * petición. Es lo que garantiza que nadie pueda consultar los datos de otra persona cambiando un
 * identificador en la URL.
 */
@Component
public class FiltroAutenticacionJwt extends OncePerRequestFilter {

    private static final String CABECERA = "Authorization";
    private static final String PREFIJO = "Bearer ";

    private final ServicioTokens tokens;

    public FiltroAutenticacionJwt(ServicioTokens tokens) {
        this.tokens = tokens;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest peticion,
                                    @NonNull HttpServletResponse respuesta,
                                    @NonNull FilterChain cadena)
            throws ServletException, IOException {

        String cabecera = peticion.getHeader(CABECERA);
        if (cabecera != null && cabecera.startsWith(PREFIJO)) {
            String token = cabecera.substring(PREFIJO.length()).trim();
            tokens.validarAccessToken(token).ifPresent(usuarioId -> {
                var autenticacion = new UsernamePasswordAuthenticationToken(
                        usuarioId, null, List.of());
                autenticacion.setDetails(
                        new WebAuthenticationDetailsSource().buildDetails(peticion));
                SecurityContextHolder.getContext().setAuthentication(autenticacion);
            });
        }
        // Un token ausente o inválido no corta la cadena aquí: deja la petición sin autenticar y
        // es la configuración de seguridad la que decide si el recurso la exigía.
        cadena.doFilter(peticion, respuesta);
    }
}
