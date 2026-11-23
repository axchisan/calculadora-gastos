package com.axchisan.gastos.dominio;

/**
 * De dónde vino un ingreso extra.
 *
 * <p>Lo importante es separar el dinero ganado del prestado: un préstamo o un avance de la tarjeta
 * entran a la cuenta igual que un pago, pero hay que devolverlos.
 */
public enum TipoIngreso {
    /** Un pago por un trabajo, una nómina o unos honorarios. */
    TRABAJO,
    /** Lo que manda la familia. */
    FAMILIA,
    /** Un préstamo o un avance: entra, pero se debe. */
    PRESTAMO,
    INTERESES,
    /** El saldo con el que empieza el mes. */
    SALDO,
    OTRO
}
