package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.ConfigTransporteMes;
import com.axchisan.gastos.dominio.DiaTransporteMes;
import com.axchisan.gastos.transporte.CalculadoraTransporte;
import com.axchisan.gastos.transporte.ResumenTransporte;
import com.axchisan.gastos.transporte.TipoDia;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/** Datos de entrada y salida del módulo de transporte. */
public final class DtosTransporte {

    private DtosTransporte() {
    }

    public record ConfigDto(BigDecimal valorPasaje, BigDecimal comisionRecarga,
                            BigDecimal presupuestoManual,
                            int pasajesDiaOficina, int pasajesExtraKarate,
                            int pasajesKarateDesdeCasa, Set<DayOfWeek> diasLaborales,
                            Set<DayOfWeek> diasKarate, int diasRemotosPorSemana) {

        public static ConfigDto de(ConfigTransporteMes config) {
            return new ConfigDto(config.getValorPasaje(), config.getComisionRecarga(),
                    config.getPresupuestoManual(),
                    config.getPasajesDiaOficina(),
                    config.getPasajesExtraKarate(), config.getPasajesKarateDesdeCasa(),
                    config.getDiasLaborales(), config.getDiasKarate(),
                    config.getDiasRemotosPorSemana());
        }
    }

    /**
     * Presupuesto puesto a mano.
     *
     * @param presupuesto lo que va a costar el mes, o nulo para volver al cálculo por calendario
     */
    public record FijarPresupuestoRequest(
            @PositiveOrZero(message = "El presupuesto no puede ser negativo")
            BigDecimal presupuesto) {
    }

    /**
     * Cambio de parámetros del transporte.
     *
     * @param regenerarClasificacion si además hay que reasignar qué días son remotos. Por defecto
     *                               no, para que cambiar la tarifa no descarte los ajustes hechos
     *                               en el calendario
     */
    public record ActualizarConfigRequest(
            @PositiveOrZero(message = "El valor del pasaje no puede ser negativo")
            BigDecimal valorPasaje,
            @PositiveOrZero(message = "La comisión no puede ser negativa")
            BigDecimal comisionRecarga,
            @Min(0) @Max(10) Integer pasajesDiaOficina,
            @Min(0) @Max(10) Integer pasajesExtraKarate,
            @Min(0) @Max(10) Integer pasajesKarateDesdeCasa,
            Set<DayOfWeek> diasLaborales,
            Set<DayOfWeek> diasKarate,
            @Min(0) @Max(7) Integer diasRemotosPorSemana,
            Boolean regenerarClasificacion) {

        public boolean debeRegenerar() {
            return Boolean.TRUE.equals(regenerarClasificacion);
        }
    }

    public record DiaDto(UUID id, LocalDate fecha, DayOfWeek diaSemana, TipoDia tipo,
                         boolean hayKarate, int pasajes, boolean overrideManual, boolean confirmado,
                         String nombreFestivo, String nota) {

        public static DiaDto de(DiaTransporteMes dia) {
            return new DiaDto(dia.getId(), dia.getFecha(), dia.getFecha().getDayOfWeek(),
                    dia.getTipo(), dia.isHayKarate(), dia.getPasajes(), dia.isOverrideManual(),
                    dia.isConfirmado(), dia.getNombreFestivo(), dia.getNota());
        }
    }

    public record CambiarTipoDiaRequest(
            @NotNull(message = "El tipo de día es obligatorio") TipoDia tipo) {
    }

    public record FijarPasajesRequest(
            @NotNull(message = "El número de pasajes es obligatorio")
            @Min(value = 0, message = "El número de pasajes no puede ser negativo")
            @Max(value = 20, message = "El número de pasajes parece excesivo")
            Integer pasajes) {
    }

    public record ConfirmarDiaRequest(
            @NotNull(message = "Indica si el día está confirmado") Boolean confirmado) {
    }

    /** Resultado del cálculo del mes. */
    public record ResumenDto(int totalPasajes, BigDecimal costoTotal, BigDecimal costoConfirmado,
                             BigDecimal costoPendiente, int diasOficina, int diasRemotos,
                             int diasFestivos, int diasKarate, int pasajesGastados,
                             List<DiaDto> dias) {

        public static ResumenDto de(ResumenTransporte resumen, List<DiaTransporteMes> filas) {
            return new ResumenDto(
                    resumen.totalPasajes(), resumen.costoTotal(), resumen.costoConfirmado(),
                    resumen.costoPendiente(), resumen.diasOficina(), resumen.diasRemotos(),
                    resumen.diasFestivos(), resumen.diasKarate(), resumen.pasajesGastados(),
                    filas.stream().map(DiaDto::de).toList());
        }
    }

    /** Proyecciones del mes según cuántos días se trabaje desde casa. */
    public record EscenariosDto(Escenario optimista, Escenario esperado, Escenario pesimista,
                                BigDecimal rango) {

        public record Escenario(int totalPasajes, BigDecimal costoTotal, int diasOficina,
                                int diasRemotos) {

            static Escenario de(ResumenTransporte r) {
                return new Escenario(r.totalPasajes(), r.costoTotal(), r.diasOficina(),
                        r.diasRemotos());
            }
        }

        public static EscenariosDto de(CalculadoraTransporte.Escenarios escenarios) {
            return new EscenariosDto(
                    Escenario.de(escenarios.optimista()),
                    Escenario.de(escenarios.esperado()),
                    Escenario.de(escenarios.pesimista()),
                    escenarios.rango());
        }
    }
}
