package com.axchisan.gastos.sueldo;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Predicate;

/**
 * Proyecta los pagos de un ingreso mensual cobrado en otra moneda.
 *
 * <p>Reglas, tal y como se pactan en un contrato de prestación de servicios habitual:
 * <ul>
 *   <li>Cada pago cubre el mes anterior y llega dentro de los primeros N días hábiles.</li>
 *   <li>Si se empieza a mitad de mes, esos días no se pagan el mes siguiente sino en el pago
 *       posterior, junto con el primer mes completo.</li>
 *   <li>Un mes incompleto se prorratea por días del calendario.</li>
 * </ul>
 *
 * <p>Es una clase sin estado ni dependencias: los días no laborables se reciben desde fuera para
 * poder probarla sin el calendario de festivos.
 */
public final class CalculadoraSueldo {

    private static final BigDecimal CIEN = BigDecimal.valueOf(100);

    /** Desde este día del mes los movimientos pertenecen al mes presupuestal siguiente. */
    private static final int DIA_DE_CORTE_DEL_MES = 28;

    private CalculadoraSueldo() {
    }

    /**
     * Los próximos pagos a partir de un mes.
     *
     * @param desde        primer mes de pago que interesa
     * @param cantidad     cuántos pagos devolver como máximo
     * @param noLaborable  indica si una fecha es fin de semana o festivo
     */
    public static List<PagoProyectado> proyectar(CondicionesCobro c, YearMonth desde,
                                                 int cantidad,
                                                 Predicate<LocalDate> noLaborable) {
        YearMonth primero = primerMesDePago(c.fechaInicio());
        YearMonth mes = desde.isAfter(primero) ? desde : primero;

        List<PagoProyectado> pagos = new ArrayList<>();
        while (pagos.size() < cantidad) {
            LocalDate inicioCubierto = mes.equals(primero)
                    ? c.fechaInicio()
                    : mes.minusMonths(1).atDay(1);
            LocalDate finCubierto = mes.minusMonths(1).atEndOfMonth();
            if (c.fechaFin() != null && c.fechaFin().isBefore(finCubierto)) {
                finCubierto = c.fechaFin();
            }
            if (inicioCubierto.isAfter(finCubierto)) {
                break;
            }
            pagos.add(pago(c, mes, inicioCubierto, finCubierto, noLaborable));
            mes = mes.plusMonths(1);
        }
        return pagos;
    }

    /**
     * Mes en que llega el primer pago.
     *
     * <p>Empezando el día 1, el mes siguiente. Empezando más tarde, el de después: los días
     * sueltos del primer mes se suman al pago del primer mes completo.
     */
    public static YearMonth primerMesDePago(LocalDate inicio) {
        YearMonth mesInicio = YearMonth.from(inicio);
        return inicio.getDayOfMonth() == 1 ? mesInicio.plusMonths(1) : mesInicio.plusMonths(2);
    }

    /** Lo que vale en la moneda original el trabajo entre dos fechas, prorrateado por mes. */
    public static BigDecimal montoEntre(BigDecimal mensual, LocalDate desde, LocalDate hasta) {
        BigDecimal total = BigDecimal.ZERO;
        YearMonth mes = YearMonth.from(desde);
        while (!mes.isAfter(YearMonth.from(hasta))) {
            LocalDate a = mes.equals(YearMonth.from(desde)) ? desde : mes.atDay(1);
            LocalDate b = mes.equals(YearMonth.from(hasta)) ? hasta : mes.atEndOfMonth();
            int dias = b.getDayOfMonth() - a.getDayOfMonth() + 1;
            if (dias == mes.lengthOfMonth()) {
                total = total.add(mensual);
            } else {
                total = total.add(mensual.multiply(BigDecimal.valueOf(dias))
                        .divide(BigDecimal.valueOf(mes.lengthOfMonth()), 6, RoundingMode.HALF_UP));
            }
            mes = mes.plusMonths(1);
        }
        return total.setScale(2, RoundingMode.HALF_UP);
    }

    /** El n-ésimo día hábil del mes (n empieza en 1). */
    public static LocalDate diaHabil(YearMonth mes, int n, Predicate<LocalDate> noLaborable) {
        LocalDate dia = mes.atDay(1);
        int contados = 0;
        while (true) {
            if (!noLaborable.test(dia)) {
                contados++;
                if (contados == n) {
                    return dia;
                }
            }
            dia = dia.plusDays(1);
        }
    }

    /** Mes presupuestal al que pertenece una fecha: del 28 en adelante cuenta el siguiente. */
    public static YearMonth mesPresupuestal(LocalDate fecha) {
        YearMonth mes = YearMonth.from(fecha);
        return fecha.getDayOfMonth() >= DIA_DE_CORTE_DEL_MES ? mes.plusMonths(1) : mes;
    }

    private static PagoProyectado pago(CondicionesCobro c, YearMonth mes, LocalDate desde,
                                       LocalDate hasta, Predicate<LocalDate> noLaborable) {
        BigDecimal bruto = montoEntre(c.montoMensual(), desde, hasta);

        BigDecimal comisiones = bruto.multiply(cero(c.comisionPorcentaje()))
                .divide(CIEN, 2, RoundingMode.HALF_UP)
                .add(cero(c.comisionFija()));
        BigDecimal neto = bruto.subtract(comisiones).max(BigDecimal.ZERO);

        BigDecimal cambio = c.trm().multiply(CIEN.subtract(cero(c.descuentoCambioPorcentaje())))
                .divide(CIEN, 6, RoundingMode.HALF_UP);
        // Se redondea hacia abajo al peso: para presupuestar es mejor quedarse corto que largo.
        BigDecimal pesos = neto.multiply(cambio).subtract(cero(c.costoRetiro()))
                .max(BigDecimal.ZERO)
                .setScale(0, RoundingMode.DOWN);

        LocalDate primerDia = diaHabil(mes, 1, noLaborable);
        LocalDate limite = diaHabil(mes, c.diasHabilesPago(), noLaborable);
        LocalDate tardia = diaHabil(mes, c.diasHabilesPago() + c.diasTolerancia(), noLaborable);
        int dias = (int) (hasta.toEpochDay() - desde.toEpochDay()) + 1;

        return new PagoProyectado(mes, desde, hasta, dias, bruto, comisiones, pesos, primerDia,
                limite, tardia, mesPresupuestal(tardia));
    }

    private static BigDecimal cero(BigDecimal valor) {
        return valor == null ? BigDecimal.ZERO : valor;
    }
}
