package com.axchisan.gastos.transporte;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.List;

/**
 * Resultado del cálculo de transporte de un mes.
 *
 * @param mes             mes calculado
 * @param dias            detalle día a día
 * @param totalPasajes    suma de pasajes del mes
 * @param costoTotal      costo total del mes
 * @param diasOficina     días de trabajo presencial
 * @param diasRemotos     días de trabajo desde casa
 * @param diasFestivos    festivos que caen en día laboral
 * @param diasKarate      días con clase de karate que generan pasaje
 * @param pasajesGastados pasajes de los días ya confirmados
 * @param costoConfirmado costo de los días ya confirmados
 */
public record ResumenTransporte(
        YearMonth mes,
        List<DiaTransporte> dias,
        int totalPasajes,
        BigDecimal costoTotal,
        int diasOficina,
        int diasRemotos,
        int diasFestivos,
        int diasKarate,
        int pasajesGastados,
        BigDecimal costoConfirmado) {

    /** Costo de los días que aún no han ocurrido. */
    public BigDecimal costoPendiente() {
        return costoTotal.subtract(costoConfirmado);
    }
}
