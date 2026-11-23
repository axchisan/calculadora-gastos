package com.axchisan.gastos.api;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.format.FormatterRegistry;
import org.springframework.http.HttpHeaders;
import org.springframework.web.filter.ShallowEtagHeaderFilter;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.io.IOException;
import java.time.YearMonth;

/**
 * Conversiones de tipos para los parámetros de las peticiones.
 *
 * <p>Varias rutas reciben un periodo en formato {@code aaaa-mm}. Registrarlo como conversión y
 * no parsearlo a mano en cada controlador tiene una ventaja concreta: un valor mal formado
 * produce el error de tipo que ya se traduce a un 400, en vez de una excepción de parseo que
 * acabaría en la red de seguridad como un 500.
 *
 * <p>También registra el {@code ETag} de las lecturas (ver {@link #etagDeLasLecturas()}).
 */
@Configuration
public class ConfiguracionWeb implements WebMvcConfigurer {

    @Override
    public void addFormatters(FormatterRegistry registro) {
        registro.addConverter(new Converter<String, YearMonth>() {
            @Override
            public YearMonth convert(String origen) {
                return YearMonth.parse(origen);
            }
        });
    }

    /**
     * {@code ETag} en todas las lecturas de la API.
     *
     * <p>La app guarda cada lectura y la vuelve a pedir por detrás cada vez que se abre una
     * pantalla. Con el {@code ETag}, si nada cambió el servidor responde {@code 304} sin cuerpo:
     * la consulta a la base se hace igual, pero no viajan los datos, que en el teléfono con
     * datos móviles es lo que más tarda. La huella se calcula sobre la respuesta ya generada,
     * así que sirve para cualquier ruta sin tocar los controladores.
     *
     * <p>Se registra después de la cadena de seguridad (orden por defecto): solo llevan huella
     * las respuestas a peticiones ya autenticadas.
     */
    @Bean
    public FilterRegistrationBean<ShallowEtagHeaderFilter> etagDeLasLecturas() {
        var registro = new FilterRegistrationBean<ShallowEtagHeaderFilter>(new EtagSinCache());
        registro.addUrlPatterns("/api/*");
        registro.setName("etagDeLasLecturas");
        return registro;
    }

    /**
     * Además del {@code ETag}, pide a cualquier caché intermedia (el navegador en la web) que no
     * sirva la copia sin preguntar antes ni la comparta: cada lectura es de un usuario.
     */
    static class EtagSinCache extends ShallowEtagHeaderFilter {
        @Override
        protected void doFilterInternal(HttpServletRequest peticion, HttpServletResponse respuesta,
                                        FilterChain cadena) throws ServletException, IOException {
            if ("GET".equals(peticion.getMethod())) {
                respuesta.setHeader(HttpHeaders.CACHE_CONTROL, "private, no-cache");
            }
            super.doFilterInternal(peticion, respuesta, cadena);
        }
    }
}
