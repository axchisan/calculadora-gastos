package com.axchisan.gastos.sueldo;

import com.axchisan.gastos.dominio.MedioCobro;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Lo pactado de un ingreso en moneda extranjera y lo que cuesta traerlo a pesos.
 *
 * @param montoMensual              lo que se cobra por un mes completo, en la moneda original
 * @param fechaFin                  último día trabajado, o {@code null} si sigue vigente
 * @param diasHabilesPago           el pago llega dentro de los primeros N días hábiles del mes
 * @param diasTolerancia            días hábiles de más que, en la práctica, puede tardar
 * @param trm                       pesos por unidad de la moneda original
 * @param comisionPorcentaje        porcentaje que el medio cobra sobre lo recibido
 * @param comisionFija              cargo fijo por pago, en la moneda original
 * @param descuentoCambioPorcentaje cuánto por debajo de la TRM convierte el medio
 * @param costoRetiro               pesos que cuesta pasar el dinero al banco
 */
public record CondicionesCobro(
        BigDecimal montoMensual,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        MedioCobro medio,
        int diasHabilesPago,
        int diasTolerancia,
        BigDecimal trm,
        BigDecimal comisionPorcentaje,
        BigDecimal comisionFija,
        BigDecimal descuentoCambioPorcentaje,
        BigDecimal costoRetiro) {
}
