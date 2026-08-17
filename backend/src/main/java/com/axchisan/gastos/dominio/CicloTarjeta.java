package com.axchisan.gastos.dominio;

import java.time.LocalDate;
import java.time.YearMonth;

/**
 * El ciclo de facturación de una tarjeta de crédito: cuándo cierra el periodo de consumo y
 * cuándo hay que pagarlo.
 *
 * <p>Es lo que responde a la pregunta que hace inmanejable una tarjeta de crédito a ojo: «esto
 * que acabo de comprar, ¿de qué mes sale?». Con corte el 15 y pago el 4:
 *
 * <pre>
 *   compra el 14 de agosto  → entra al corte del 15 de agosto     → se paga el 4 de septiembre
 *   compra el 15 de agosto  → entra al corte del 15 de agosto     → se paga el 4 de septiembre
 *   compra el 16 de agosto  → ya no alcanza; corte del 15 de sept → se paga el 4 de octubre
 * </pre>
 *
 * <p>Dos días de diferencia en la compra desplazan el pago un mes entero. Esa es la razón de
 * que la aplicación lo calcule en lugar de pedirle al usuario que elija el mes: es justo el
 * tipo de cuenta que se hace mal cuando se hace de memoria.
 *
 * @param diaCorte día del mes en que cierra el periodo de consumo; el propio día entra
 * @param diaPago  día del mes siguiente al corte en que vence el pago
 */
public record CicloTarjeta(int diaCorte, int diaPago) {

    public CicloTarjeta {
        // Se limita a 28 para que el día exista en todos los meses, febrero incluido. Ningún
        // banco pone el corte más allá y así no hay que decidir qué significa «el 31» en abril.
        if (diaCorte < 1 || diaCorte > 28) {
            throw new IllegalArgumentException("El día de corte debe estar entre 1 y 28");
        }
        if (diaPago < 1 || diaPago > 28) {
            throw new IllegalArgumentException("El día de pago debe estar entre 1 y 28");
        }
    }

    /** Mes cuyo corte recoge una compra hecha en esta fecha. */
    public YearMonth corteDe(LocalDate compra) {
        YearMonth mes = YearMonth.from(compra);
        // Pasado el día de corte, la compra ya no cabe en el periodo que acaba de cerrar y
        // queda para el siguiente.
        return compra.getDayOfMonth() > diaCorte ? mes.plusMonths(1) : mes;
    }

    /** Mes en el que hay que pagar una compra hecha en esta fecha. */
    public YearMonth periodoDePago(LocalDate compra) {
        return corteDe(compra).plusMonths(1);
    }

    /** Fecha exacta en que vence el pago de una compra hecha en esta fecha. */
    public LocalDate vencimientoDe(LocalDate compra) {
        return periodoDePago(compra).atDay(diaPago);
    }

    /**
     * Cuántos días de financiación gratis da una compra hecha en esta fecha.
     *
     * <p>Sirve para lo que en la práctica se hace a ojo: comprar justo después del corte
     * estira el plazo casi dos meses, comprar justo antes lo deja en tres semanas.
     */
    public long diasHastaElPago(LocalDate compra) {
        return java.time.temporal.ChronoUnit.DAYS.between(compra, vencimientoDe(compra));
    }
}
