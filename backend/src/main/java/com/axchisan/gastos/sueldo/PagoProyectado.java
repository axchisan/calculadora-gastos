package com.axchisan.gastos.sueldo;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;

/**
 * Un pago que se espera recibir, con el periodo que cubre y su valor en pesos.
 *
 * @param mesDePago        mes del calendario en que se paga
 * @param desde            primer día trabajado que cubre
 * @param hasta            último día trabajado que cubre
 * @param diasCubiertos    días del calendario entre {@code desde} y {@code hasta}
 * @param montoOriginal    lo que se paga en la moneda pactada, ya prorrateado
 * @param comisiones       lo que se queda el medio de cobro, en la moneda pactada
 * @param montoPesos       lo que se estima que llega a la cuenta
 * @param primerDiaPosible primer día hábil del mes de pago
 * @param fechaLimite      último de los días hábiles pactados
 * @param fechaTardia      hasta dónde puede estirarse en la práctica
 * @param mesPresupuestal  mes de la aplicación en el que entra (el mes va del 28 al 27)
 */
public record PagoProyectado(
        YearMonth mesDePago,
        LocalDate desde,
        LocalDate hasta,
        int diasCubiertos,
        BigDecimal montoOriginal,
        BigDecimal comisiones,
        BigDecimal montoPesos,
        LocalDate primerDiaPosible,
        LocalDate fechaLimite,
        LocalDate fechaTardia,
        YearMonth mesPresupuestal) {

    /** Si es un pago que no cubre un mes completo. */
    public boolean esProrrateado() {
        return !(desde.getDayOfMonth() == 1
                && hasta.equals(YearMonth.from(desde).atEndOfMonth())
                && YearMonth.from(desde).equals(YearMonth.from(hasta)));
    }
}
