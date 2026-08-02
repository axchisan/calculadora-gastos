package com.axchisan.gastos.dominio;

/** Regla con la que una meta de ahorro reclama dinero del mes. */
public enum TipoAsignacion {

    /** Un porcentaje del ingreso total del mes. */
    PORCENTAJE_INGRESO,

    /** Una cantidad fija, independiente de lo que se ingrese. */
    MONTO_FIJO,

    /**
     * Un porcentaje de lo que sobra tras cubrir gastos y deudas.
     *
     * <p>Permite reglas del tipo «la mitad de lo que sobre va al fondo de emergencia», y por eso
     * se calcula después que las otras dos.
     */
    PORCENTAJE_SOBRANTE
}
