package com.axchisan.gastos.api;

import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.format.FormatterRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.time.YearMonth;

/**
 * Conversiones de tipos para los parámetros de las peticiones.
 *
 * <p>Varias rutas reciben un periodo en formato {@code aaaa-mm}. Registrarlo como conversión y
 * no parsearlo a mano en cada controlador tiene una ventaja concreta: un valor mal formado
 * produce el error de tipo que ya se traduce a un 400, en vez de una excepción de parseo que
 * acabaría en la red de seguridad como un 500.
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
}
