package com.axchisan.gastos.dominio;

/** Naturaleza de una tarjeta. Determina si sus compras salen del dinero de hoy o del de después. */
public enum TipoTarjeta {

    DEBITO,
    CREDITO;

    /** El medio de pago que corresponde a las compras hechas con esta tarjeta. */
    public MedioPago medioPago() {
        return this == CREDITO ? MedioPago.CREDITO : MedioPago.DEBITO;
    }
}
