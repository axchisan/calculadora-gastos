package com.axchisan.gastos.calendario;

/** Origen de un festivo colombiano, según cómo se determina su fecha. */
public enum TipoFestivo {

    /** Fecha fija que nunca se traslada (Navidad, Año Nuevo, 20 de julio...). */
    FIJO,

    /** Fecha fija que la Ley Emiliani traslada al lunes siguiente si no cae en lunes. */
    TRASLADADO,

    /** Fecha derivada del Domingo de Resurrección. */
    PASCUA
}
