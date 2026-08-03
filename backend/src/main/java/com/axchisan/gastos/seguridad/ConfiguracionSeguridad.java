package com.axchisan.gastos.seguridad;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;
import java.util.Map;

@Configuration
@EnableWebSecurity
public class ConfiguracionSeguridad {

    /**
     * Rutas accesibles sin token de acceso.
     *
     * <p>{@code /logout} está aquí a propósito: el caso habitual es volver a la aplicación horas
     * después, con el token de acceso ya caducado, y querer cerrar la sesión. Exigir un token
     * válido obligaría a renovarlo solo para poder cerrarla. No abre ningún hueco, porque la
     * operación únicamente revoca el token de refresco que el propio llamante presenta: quien lo
     * tenga ya podría hacer bastante más que cerrar la sesión.
     */
    private static final String[] RUTAS_PUBLICAS = {
            "/api/auth/registro", "/api/auth/login", "/api/auth/refresh", "/api/auth/logout",
            "/api/auth/registro-abierto",
            "/api/salud", "/docs/**", "/v3/api-docs/**", "/swagger-ui/**"
    };

    private final List<String> origenesPermitidos;
    private final int costeBcrypt;

    /**
     * @param costeBcrypt coste de BCrypt. Con 12, cada verificación tarda unos cientos de
     *                    milisegundos, lo que encarece los ataques por diccionario sin afectar al
     *                    uso normal. Se baja únicamente en las pruebas, donde ese retardo se
     *                    multiplicaría por cada caso.
     */
    public ConfiguracionSeguridad(@Value("${app.cors.allowed-origins}") List<String> origenes,
                                  @Value("${app.seguridad.bcrypt-coste:12}") int costeBcrypt) {
        this.origenesPermitidos = origenes;
        this.costeBcrypt = costeBcrypt;
    }

    @Bean
    public SecurityFilterChain cadenaFiltros(HttpSecurity http, FiltroAutenticacionJwt filtroJwt,
                                             ObjectMapper json) throws Exception {
        return http
                // La API no usa cookies de sesión, así que no hay superficie para CSRF.
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(configuracionCors()))
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(rutas -> rutas
                        .requestMatchers(RUTAS_PUBLICAS).permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e.authenticationEntryPoint((peticion, respuesta, ex) -> {
                    respuesta.setStatus(HttpStatus.UNAUTHORIZED.value());
                    respuesta.setContentType(MediaType.APPLICATION_JSON_VALUE);
                    respuesta.setCharacterEncoding("UTF-8");
                    json.writeValue(respuesta.getWriter(), Map.of(
                            "error", "no_autenticado",
                            "mensaje", "Se requiere iniciar sesión"));
                }))
                .addFilterBefore(filtroJwt,
                        org.springframework.security.web.authentication
                                .UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    @Bean
    public PasswordEncoder codificadorContrasenas() {
        return new BCryptPasswordEncoder(costeBcrypt);
    }

    @Bean
    public CorsConfigurationSource configuracionCors() {
        CorsConfiguration configuracion = new CorsConfiguration();
        configuracion.setAllowedOriginPatterns(origenesPermitidos);
        configuracion.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuracion.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        configuracion.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource fuente = new UrlBasedCorsConfigurationSource();
        fuente.registerCorsConfiguration("/**", configuracion);
        return fuente;
    }
}
