package com.axchisan.gastos.dominio;

/**
 * Procedencia de un gasto del mes.
 *
 * <p>Distingue los que crea el usuario de los que genera el sistema, que no se editan
 * directamente sino desde su propio módulo.
 */
public enum OrigenGasto {

    /** Creado a mano para este mes concreto. */
    MANUAL,

    /** Copiado de una plantilla de gastos fijos al crear el mes. */
    PLANTILLA,

    /** Refleja el resultado del cálculo de transporte; se edita desde el calendario. */
    TRANSPORTE,

    /** Refleja un abono a una deuda; se edita desde el módulo de deudas. */
    DEUDA;

    /** Indica si el gasto se gestiona desde otro módulo en lugar de editarse directamente. */
    public boolean esGeneradoPorElSistema() {
        return this == TRANSPORTE || this == DEUDA;
    }
}
