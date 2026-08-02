package com.axchisan.gastos.dominio;

import com.fasterxml.uuid.Generators;
import com.fasterxml.uuid.NoArgGenerator;

import java.util.UUID;

/**
 * Generador de identificadores para las entidades.
 *
 * <p>Se usan UUID <b>v7</b>, que incorporan una marca de tiempo en los bits más significativos.
 * A diferencia de los v4 aleatorios, las claves consecutivas quedan próximas entre sí, lo que
 * conserva la localidad en los índices B-tree y evita la fragmentación al insertar. Además
 * ordenan cronológicamente sin necesidad de consultar {@code created_at}.
 */
public final class Identificadores {

    private static final NoArgGenerator GENERADOR = Generators.timeBasedEpochGenerator();

    private Identificadores() {
    }

    /** Genera un nuevo identificador UUID v7. */
    public static UUID nuevo() {
        return GENERADOR.generate();
    }
}
