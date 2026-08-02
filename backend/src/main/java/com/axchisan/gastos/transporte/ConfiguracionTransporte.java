package com.axchisan.gastos.transporte;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.util.EnumSet;
import java.util.Set;

/**
 * Parámetros del cálculo de transporte para un mes.
 *
 * <p>Todos los valores son configurables desde la interfaz, porque tanto la tarifa del pasaje
 * como la rutina de trabajo o de actividades pueden cambiar de un mes a otro.
 *
 * @param valorPasaje             costo de un pasaje sencillo
 * @param pasajesDiaOficina       pasajes de un día presencial normal (casa → oficina → casa)
 * @param pasajesExtraKarate      pasajes adicionales si hay karate un día de oficina; el
 *                                recorrido pasa a ser casa → oficina → karate → casa
 * @param pasajesKarateDesdeCasa  pasajes si hay karate en un día no presencial
 *                                (casa → karate → casa)
 * @param diasLaborales           días de la semana en que se trabaja
 * @param diasKarate              días de la semana con clase de karate
 */
public record ConfiguracionTransporte(
        BigDecimal valorPasaje,
        int pasajesDiaOficina,
        int pasajesExtraKarate,
        int pasajesKarateDesdeCasa,
        Set<DayOfWeek> diasLaborales,
        Set<DayOfWeek> diasKarate) {

    public ConfiguracionTransporte {
        if (valorPasaje == null || valorPasaje.signum() < 0) {
            throw new IllegalArgumentException("El valor del pasaje no puede ser negativo");
        }
        if (pasajesDiaOficina < 0 || pasajesExtraKarate < 0 || pasajesKarateDesdeCasa < 0) {
            throw new IllegalArgumentException("El número de pasajes no puede ser negativo");
        }
        diasLaborales = diasLaborales == null || diasLaborales.isEmpty()
                ? EnumSet.noneOf(DayOfWeek.class)
                : EnumSet.copyOf(diasLaborales);
        diasKarate = diasKarate == null || diasKarate.isEmpty()
                ? EnumSet.noneOf(DayOfWeek.class)
                : EnumSet.copyOf(diasKarate);
    }

    /** Configuración por defecto: jornada de lunes a viernes con karate martes y jueves. */
    public static ConfiguracionTransporte porDefecto(BigDecimal valorPasaje) {
        return new ConfiguracionTransporte(
                valorPasaje,
                2,
                1,
                2,
                EnumSet.of(DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY,
                        DayOfWeek.THURSDAY, DayOfWeek.FRIDAY),
                EnumSet.of(DayOfWeek.TUESDAY, DayOfWeek.THURSDAY));
    }

    /** Indica si el día de la semana corresponde a jornada laboral. */
    public boolean esDiaLaboral(DayOfWeek dia) {
        return diasLaborales.contains(dia);
    }

    /** Indica si el día de la semana tiene clase de karate. */
    public boolean tieneKarate(DayOfWeek dia) {
        return diasKarate.contains(dia);
    }
}
