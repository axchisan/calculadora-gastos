package com.axchisan.gastos.calendario;

import java.time.LocalDate;

/**
 * Un día festivo en Colombia.
 *
 * @param fecha         fecha en que efectivamente se celebra
 * @param nombre        nombre del festivo
 * @param tipo          cómo se determinó la fecha
 * @param fechaOriginal fecha antes del traslado de la Ley Emiliani; igual a {@code fecha}
 *                      cuando no hubo traslado
 */
public record Festivo(LocalDate fecha, String nombre, TipoFestivo tipo, LocalDate fechaOriginal) {

    /** Indica si la Ley Emiliani movió el festivo respecto de su fecha original. */
    public boolean fueTrasladado() {
        return !fecha.equals(fechaOriginal);
    }
}
