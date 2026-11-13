package com.axchisan.gastos.dominio;

/** Cómo llega a Colombia un ingreso cobrado en otra moneda. */
public enum MedioCobro {
    /** Transferencia directa a una cuenta en pesos, convertida a la TRM o cerca de ella. */
    TRANSFERENCIA,
    /** Pago por PayPal: comisión por recibir, cambio por debajo de la TRM y costo de retiro. */
    PAYPAL
}
