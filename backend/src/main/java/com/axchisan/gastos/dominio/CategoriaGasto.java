package com.axchisan.gastos.dominio;

/**
 * Clasificación de un gasto o de una compra, usada para agrupar en las gráficas.
 *
 * <p>Las últimas categorías nacieron con las compras del día a día: los gastos fijos son media
 * docena de conceptos grandes y se distinguen solos, pero el día a día son muchos importes
 * pequeños que sin grano suficiente acaban todos en «otro» y no explican nada.
 */
public enum CategoriaGasto {
    VIVIENDA,
    ALIMENTACION,
    TRANSPORTE,
    SERVICIOS,
    SUSCRIPCIONES,
    SALUD,
    EDUCACION,
    DEPORTE,
    HERRAMIENTAS,
    DEUDA,
    AHORRO,

    /** Gustos: bebidas, snacks, lo que se compra por antojo y no por necesidad. */
    ANTOJOS,
    CUIDADO_PERSONAL,
    /** Comisiones de cajero, cuotas de manejo y demás mordiscos del banco. */
    COMISIONES,
    OCIO,
    ROPA,
    HOGAR,
    OTRO
}
