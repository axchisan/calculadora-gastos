package com.axchisan.gastos.deteccion;

/** Qué tipo de movimiento cuenta un aviso del banco. */
public enum ClaseMovimiento {
    COMPRA(false),
    PAGO(false),
    TRANSFERENCIA_ENVIADA(false),
    RETIRO(false),
    PAGO_QR(false),
    COMISION(false),
    TRANSFERENCIA_RECIBIDA(true),
    NOMINA(true),
    INTERESES(true);

    private final boolean entra;

    ClaseMovimiento(boolean entra) {
        this.entra = entra;
    }

    /** Si es dinero que entra a la cuenta. */
    public boolean entra() {
        return entra;
    }
}
