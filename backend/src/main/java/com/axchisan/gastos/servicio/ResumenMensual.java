package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CategoriaGasto;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

/**
 * Fotografía completa de un mes.
 *
 * <p>La distinción clave es entre <b>disponible hoy</b> y <b>saldo proyectado</b>: el primero
 * cuenta solo lo efectivamente pagado y responde a «¿cuánto tengo ahora?»; el segundo asume que
 * todo lo pendiente se pagará y responde a «¿cómo cierra el mes?». Ver los dos a la vez evita la
 * ilusión de tener dinero que en realidad ya está comprometido.
 *
 * @param mesId                       identificador del mes
 * @param periodo                     año y mes
 * @param cerrado                     si el mes ya se cerró
 * @param ingresoBase                 sueldo del mes
 * @param ingresosAdicionalesCobrados extras ya recibidos
 * @param ingresosAdicionalesTotales  extras previstos, cobrados o no
 * @param ingresoTotal                sueldo más extras ya cobrados
 * @param ingresoProyectado           sueldo más todos los extras previstos
 * @param gastoTotal                  suma de todos los gastos del mes
 * @param gastoPagado                 lo ya abonado
 * @param gastoPendiente              lo que falta por pagar
 * @param abonosDeuda                 abonos a deudas imputados a este mes
 * @param aporteAhorro                aportes menos retiros de ahorro en este mes
 * @param disponibleHoy               dinero libre contando solo lo ya pagado
 * @param saldoProyectado             dinero que quedará al cerrar el mes
 * @param deudaTotal                  saldo pendiente de todas las deudas activas
 * @param ahorroTotal                 saldo acumulado en todas las metas
 * @param patrimonioNeto              ahorro menos deuda
 * @param comprometido                todo lo que tiene destino este mes: gastos, abonos a
 *                                    deudas y aportes al ahorro, se hayan pagado o no
 * @param porcentajeComprometido      qué parte del ingreso previsto ya tiene destino
 * @param cuotasDeudaPendientes       lo que falta abonar este mes según las cuotas pactadas
 * @param comprometidoConCuotas       lo comprometido más las cuotas de deuda aún por pagar
 * @param deudasSinCuota              deudas activas sin cuota mensual, que no pueden proyectarse
 * @param porCategoria                reparto del gasto por categoría
 */
public record ResumenMensual(
        UUID mesId,
        YearMonth periodo,
        boolean cerrado,
        BigDecimal ingresoBase,
        BigDecimal ingresosAdicionalesCobrados,
        BigDecimal ingresosAdicionalesTotales,
        BigDecimal ingresoTotal,
        BigDecimal ingresoProyectado,
        BigDecimal gastoTotal,
        BigDecimal gastoPagado,
        BigDecimal gastoPendiente,
        BigDecimal abonosDeuda,
        BigDecimal aporteAhorro,
        BigDecimal disponibleHoy,
        BigDecimal saldoProyectado,
        BigDecimal deudaTotal,
        BigDecimal ahorroTotal,
        BigDecimal patrimonioNeto,
        BigDecimal comprometido,
        BigDecimal porcentajeComprometido,
        BigDecimal cuotasDeudaPendientes,
        BigDecimal comprometidoConCuotas,
        long deudasSinCuota,
        List<TotalCategoria> porCategoria) {

    /** Gasto acumulado de una categoría dentro del mes. */
    public record TotalCategoria(CategoriaGasto categoria, BigDecimal total,
                                 BigDecimal porcentaje) {
    }

    /** Indica si el mes cierra en positivo. */
    public boolean cierraEnPositivo() {
        return saldoProyectado.signum() >= 0;
    }

    /** Indica si los compromisos, cuotas de deuda incluidas, superan lo que se espera ingresar. */
    public boolean estaSobrecomprometido() {
        return comprometidoConCuotas.compareTo(ingresoProyectado) > 0;
    }

    /** Lo que quedaría libre tras atender también las cuotas de deuda del mes. */
    public BigDecimal saldoTrasCuotas() {
        return ingresoProyectado.subtract(comprometidoConCuotas);
    }
}
