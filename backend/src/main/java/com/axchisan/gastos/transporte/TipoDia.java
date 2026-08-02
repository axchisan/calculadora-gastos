package com.axchisan.gastos.transporte;

/** Clasificación de un día del mes a efectos del gasto en transporte. */
public enum TipoDia {

    /** Día de trabajo presencial: se paga ida y vuelta. */
    OFICINA(true),

    /** Día de trabajo desde casa: no hay desplazamiento laboral. */
    REMOTO(false),

    /** Festivo colombiano. */
    FESTIVO(false),

    /** Sábado o domingo. */
    FIN_DE_SEMANA(false),

    /** Vacaciones: no hay desplazamiento, tampoco a actividades. */
    VACACIONES(false),

    /** Incapacidad, permiso o cualquier ausencia. */
    AUSENTE(false);

    private final boolean requiereDesplazamientoLaboral;

    TipoDia(boolean requiereDesplazamientoLaboral) {
        this.requiereDesplazamientoLaboral = requiereDesplazamientoLaboral;
    }

    /** Indica si ese día hay que ir a la oficina. */
    public boolean requiereDesplazamientoLaboral() {
        return requiereDesplazamientoLaboral;
    }

    /**
     * Indica si el día impide cualquier desplazamiento, incluidas las actividades personales
     * como el karate.
     */
    public boolean impideActividades() {
        return this == VACACIONES || this == AUSENTE;
    }
}
