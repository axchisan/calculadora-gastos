package com.axchisan.gastos.transporte;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Un día del mes ya clasificado, con los pasajes que le corresponden.
 *
 * @param fecha          día del calendario
 * @param tipo           clasificación del día
 * @param hayKarate      si ese día hay clase de karate
 * @param pasajes        pasajes calculados, o el valor manual si {@code overrideManual}
 * @param overrideManual si el usuario fijó los pasajes a mano; protege el valor de los
 *                       recálculos automáticos
 * @param confirmado     si el día ya transcurrió y se confirmó lo realmente gastado
 * @param nombreFestivo  nombre del festivo, si aplica
 */
public record DiaTransporte(
        LocalDate fecha,
        TipoDia tipo,
        boolean hayKarate,
        int pasajes,
        boolean overrideManual,
        boolean confirmado,
        String nombreFestivo) {

    /** Costo del día. */
    public BigDecimal costo(BigDecimal valorPasaje) {
        return valorPasaje.multiply(BigDecimal.valueOf(pasajes));
    }

    /** Copia el día cambiando su clasificación; descarta el override manual. */
    public DiaTransporte conTipo(TipoDia nuevoTipo) {
        return new DiaTransporte(fecha, nuevoTipo, hayKarate, pasajes, false, confirmado,
                nombreFestivo);
    }

    /** Copia el día fijando los pasajes a mano. */
    public DiaTransporte conPasajesManuales(int pasajesManuales) {
        return new DiaTransporte(fecha, tipo, hayKarate, pasajesManuales, true, confirmado,
                nombreFestivo);
    }
}
