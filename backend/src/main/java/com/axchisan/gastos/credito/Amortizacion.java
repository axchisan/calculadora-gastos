package com.axchisan.gastos.credito;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;

/**
 * Las cuentas del sistema francés, que es con el que se amortizan estos créditos.
 *
 * <p>Francés quiere decir cuota constante: cada mes se paga lo mismo, pero por dentro el reparto
 * cambia. Al principio casi todo es interés y casi nada mata deuda; al final, al revés. Esa es
 * la razón de que adelantar dinero pronto ahorre tanto y tarde ahorre poco.
 *
 * <p>Con una tasa del 76% efectivo anual la diferencia no es teórica: de los 4,4 millones
 * prestados se devuelven 6,7. Poder calcular qué pasa si se abona de más es lo que convierte
 * esa cifra en una decisión en vez de en un susto.
 */
public final class Amortizacion {

    /** Precisión de trabajo. Se redondea solo al presentar, nunca en los pasos intermedios. */
    private static final MathContext PRECISION = new MathContext(20, RoundingMode.HALF_UP);

    private static final BigDecimal CIEN = BigDecimal.valueOf(100);
    private static final int MESES = 12;

    private Amortizacion() {
    }

    /**
     * Convierte una tasa efectiva anual en la mensual equivalente.
     *
     * <p>No se divide entre doce. El interés se capitaliza, así que la mensual es la raíz
     * duodécima: {@code (1 + ea)^(1/12) - 1}. Dividir daría 6,33% mensual en lugar del 4,82%
     * real, y todo el cuadro saldría inflado casi un tercio.
     *
     * @param tasaEaPorcentaje la tasa tal y como la publica el banco, en porcentaje (76.0)
     */
    public static double mensualDesdeEfectivaAnual(double tasaEaPorcentaje) {
        return Math.pow(1 + tasaEaPorcentaje / 100.0, 1.0 / MESES) - 1;
    }

    /**
     * La cuota constante que amortiza un saldo en un número de meses.
     *
     * <pre>
     *   cuota = saldo · i / (1 - (1 + i)^-n)
     * </pre>
     *
     * <p>Solo cubre capital e interés. Los cargos fijos —seguro, Mipyme— van aparte porque no
     * dependen del saldo de la misma forma y el banco los suma después.
     */
    public static BigDecimal cuota(BigDecimal saldo, double mensual, int cuotas) {
        if (cuotas <= 0) {
            throw new IllegalArgumentException("El número de cuotas debe ser mayor que cero");
        }
        if (saldo.signum() <= 0) {
            return BigDecimal.ZERO;
        }
        // Sin interés, la cuota es el simple reparto del saldo.
        if (mensual <= 0) {
            return saldo.divide(BigDecimal.valueOf(cuotas), 2, RoundingMode.HALF_UP);
        }

        double factor = 1 - Math.pow(1 + mensual, -cuotas);
        return saldo.multiply(BigDecimal.valueOf(mensual), PRECISION)
                .divide(BigDecimal.valueOf(factor), 2, RoundingMode.HALF_UP);
    }

    /**
     * Cuántas cuotas hacen falta para saldar un saldo pagando siempre lo mismo.
     *
     * <pre>
     *   n = -ln(1 - saldo · i / cuota) / ln(1 + i)
     * </pre>
     *
     * <p>Es la pregunta inversa de {@link #cuota}, y la que responde «si sigo pagando lo mismo,
     * ¿cuándo termino?» después de un abono extraordinario.
     *
     * @return el número de cuotas, redondeado hacia arriba porque la última siempre es menor
     * @throws IllegalArgumentException si la cuota no llega ni para cubrir el interés del mes,
     *                                  en cuyo caso la deuda nunca se acabaría
     */
    public static int cuotasNecesarias(BigDecimal saldo, double mensual, BigDecimal cuota) {
        if (saldo.signum() <= 0) {
            return 0;
        }
        if (mensual <= 0) {
            return (int) Math.ceil(saldo.doubleValue() / cuota.doubleValue());
        }

        double interesDelPrimerMes = saldo.doubleValue() * mensual;
        if (cuota.doubleValue() <= interesDelPrimerMes) {
            throw new IllegalArgumentException(
                    "Con esa cuota no se cubre ni el interés del mes: la deuda crecería");
        }

        double dentro = 1 - (saldo.doubleValue() * mensual / cuota.doubleValue());
        return (int) Math.ceil(-Math.log(dentro) / Math.log(1 + mensual));
    }

    /**
     * El interés total que generará un saldo hasta terminar de pagarlo.
     *
     * <p>Se calcula recorriendo el cuadro mes a mes y no con una fórmula cerrada porque el
     * redondeo a pesos de cada cuota se acumula, y la diferencia contra lo que cobra el banco
     * sería de varios miles al final del plan.
     */
    public static BigDecimal interesTotal(BigDecimal saldo, double mensual, int cuotas) {
        BigDecimal cuota = cuota(saldo, mensual, cuotas);
        BigDecimal pendiente = saldo;
        BigDecimal total = BigDecimal.ZERO;

        for (int i = 0; i < cuotas && pendiente.signum() > 0; i++) {
            BigDecimal interes = pendiente
                    .multiply(BigDecimal.valueOf(mensual), PRECISION)
                    .setScale(2, RoundingMode.HALF_UP);

            BigDecimal aCapital = cuota.subtract(interes);
            // La última cuota salda lo que quede, aunque sea menos que la cuota completa.
            if (aCapital.compareTo(pendiente) > 0) {
                aCapital = pendiente;
            }

            total = total.add(interes);
            pendiente = pendiente.subtract(aCapital);
        }
        return total;
    }

    /** Porcentaje que representa una parte de un total, entre 0 y 100. */
    public static BigDecimal porcentaje(BigDecimal parte, BigDecimal total) {
        if (total.signum() == 0) {
            return BigDecimal.ZERO;
        }
        return parte.multiply(CIEN).divide(total, 2, RoundingMode.HALF_UP);
    }
}
