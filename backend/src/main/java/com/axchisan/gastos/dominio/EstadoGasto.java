package com.axchisan.gastos.dominio;

/** Situación de pago de un gasto. */
public enum EstadoGasto {

    /** Sin abonar nada. */
    PENDIENTE,

    /** Abonado en parte. */
    PARCIAL,

    /** Saldado por completo. */
    PAGADO
}
