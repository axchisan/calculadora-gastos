package com.axchisan.gastos.deteccion;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Un movimiento tal como lo cuenta un aviso del banco (correo, SMS) o una línea de un extracto.
 *
 * @param clase       qué tipo de movimiento es
 * @param monto       siempre positivo; el signo lo da {@link #entra()}
 * @param hora        null si la fuente no la trae (el PDF de movimientos no la tiene)
 * @param cuenta      últimos dígitos del producto propio, si el aviso los dice
 * @param contraparte comercio, entidad, destinatario o remitente
 * @param referencia  cuenta, llave o celular de la contraparte, si viene
 */
public record AvisoBancario(String banco, ClaseMovimiento clase, BigDecimal monto,
                            LocalDate fecha, LocalTime hora, String cuenta,
                            String contraparte, String referencia) {

    public boolean entra() {
        return clase.entra();
    }

    /** El monto con signo: positivo si entra, negativo si sale. */
    public BigDecimal montoConSigno() {
        return entra() ? monto : monto.negate();
    }
}
