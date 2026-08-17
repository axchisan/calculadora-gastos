package com.axchisan.gastos.dominio;

/**
 * De dónde salió el dinero de una compra.
 *
 * <p>La distinción no es cosmética: determina <em>cuándo</em> sale el dinero. Con efectivo y
 * débito sale en el acto; con crédito sale cuando vence el corte de la tarjeta, que puede ser
 * uno o dos meses después.
 */
public enum MedioPago {

    EFECTIVO,

    /** Débito, incluida la tarjeta añadida a la billetera del teléfono. */
    DEBITO,

    /** Crédito: la compra no toca el dinero de este mes, sino el del mes en que vence. */
    CREDITO;

    /** Indica si el dinero sale en el momento de la compra. */
    public boolean saleAlInstante() {
        return this != CREDITO;
    }
}
