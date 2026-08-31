package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.Credito;
import com.axchisan.gastos.dominio.CuotaCredito;
import com.axchisan.gastos.servicio.ServicioCreditos;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Datos de entrada y salida de los créditos con cuadro de amortización. */
public final class DtosCredito {

    private DtosCredito() {
    }

    /**
     * Un crédito con su estado actual.
     *
     * @param saldo            capital que se debe hoy
     * @param costeTotal       lo que el crédito cuesta por encima de lo prestado
     * @param porcentajePagado qué parte se lleva pagada, medida en dinero
     */
    public record CreditoDto(UUID id, String entidad, String numeroOperacion, String descripcion,
                             BigDecimal montoOriginal, BigDecimal tasaEa, int plazoCuotas,
                             Short diaPago, LocalDate fechaVencimiento, boolean activo,
                             int cuotasTotales, int cuotasPagadas, int cuotasVencidas,
                             BigDecimal saldo, BigDecimal capitalPagado, BigDecimal interesPagado,
                             BigDecimal totalPagado, BigDecimal capitalPendiente,
                             BigDecimal interesPendiente, BigDecimal totalPendiente,
                             BigDecimal costeTotal, BigDecimal porcentajePagado,
                             CuotaDto proximaCuota) {

        public static CreditoDto de(ServicioCreditos.EstadoCredito estado) {
            Credito c = estado.credito();
            return new CreditoDto(
                    c.getId(), c.getEntidad(), c.getNumeroOperacion(), c.getDescripcion(),
                    c.getMontoOriginal(), c.getTasaEa(), c.getPlazoCuotas(), c.getDiaPago(),
                    c.getFechaVencimiento(), c.isActivo(),
                    estado.cuotasTotales(), estado.cuotasPagadas(), estado.cuotasVencidas(),
                    estado.saldo(), estado.capitalPagado(), estado.interesPagado(),
                    estado.totalPagado(), estado.capitalPendiente(), estado.interesPendiente(),
                    estado.totalPendiente(), estado.costeTotal(), estado.porcentajePagado(),
                    estado.proximaCuota() == null ? null : CuotaDto.de(estado.proximaCuota()));
        }
    }

    /**
     * Una cuota del cuadro.
     *
     * @param saldoCapital lo que se debe justo antes de pagarla
     * @param cargos       todo lo que no es capital ni interés: seguro, Mipyme, mora
     */
    public record CuotaDto(UUID id, int numero, LocalDate fecha, Short dias,
                           BigDecimal saldoCapital, BigDecimal capital, BigDecimal interes,
                           BigDecimal mora, BigDecimal mipyme, BigDecimal seguro,
                           BigDecimal otros, BigDecimal cargos, BigDecimal valorCuota,
                           boolean pagada, LocalDate fechaPago, BigDecimal montoPagado,
                           String periodo) {

        public static CuotaDto de(CuotaCredito q) {
            return new CuotaDto(q.getId(), q.getNumero(), q.getFecha(), q.getDias(),
                    q.getSaldoCapital(), q.getCapital(), q.getInteres(), q.getMora(),
                    q.getMipyme(), q.getSeguro(), q.getOtros(), q.cargos(), q.getValorCuota(),
                    q.isPagada(), q.getFechaPago(), q.getMontoPagado(),
                    q.periodo().toString());
        }
    }

    public record CrearCreditoRequest(

            @NotBlank(message = "La entidad es obligatoria")
            @Size(max = 60) String entidad,

            @Size(max = 40) String numeroOperacion,
            @Size(max = 120) String descripcion,

            @NotNull(message = "El monto es obligatorio")
            @Positive(message = "El monto debe ser mayor que cero")
            BigDecimal montoOriginal,

            @PositiveOrZero(message = "La tasa no puede ser negativa")
            BigDecimal tasaEa,

            @NotNull @Min(value = 1, message = "El plazo debe ser de al menos una cuota")
            Integer plazoCuotas,

            @Min(1) Integer diaPago,
            LocalDate fechaDesembolso,
            LocalDate fechaVencimiento,

            @NotEmpty(message = "Hay que enviar el cuadro de amortización")
            @Valid List<CuotaDelPlan> cuotas) {
    }

    /** Una fila del cuadro tal y como la imprime el banco. */
    public record CuotaDelPlan(
            @NotNull @Min(1) Integer numero,
            @NotNull LocalDate fecha,
            Integer dias,
            @NotNull @PositiveOrZero BigDecimal saldoCapital,
            @NotNull @PositiveOrZero BigDecimal capital,
            @NotNull @PositiveOrZero BigDecimal interes,
            @PositiveOrZero BigDecimal mora,
            @PositiveOrZero BigDecimal mipyme,
            @PositiveOrZero BigDecimal seguro,
            @PositiveOrZero BigDecimal otros,
            @NotNull @PositiveOrZero BigDecimal valorCuota,
            Boolean pagada,
            LocalDate fechaPago) {
    }

    public record MarcarCuotaRequest(
            @NotNull(message = "Hay que indicar si la cuota queda pagada") Boolean pagada,
            LocalDate fecha,
            @PositiveOrZero BigDecimal monto) {
    }

    /**
     * Lo que cambiaría al abonar de más.
     *
     * @param ahorroInteres   intereses que ese capital ya no genera
     * @param cuotasAhorradas cuántas cuotas desaparecen
     * @param ahorroNeto      lo que se deja de pagar en total, descontando el propio abono
     * @param rendimiento     cuánto se ahorra por cada cien pesos adelantados
     */
    public record SimulacionDto(BigDecimal abono, String modo,
                                int cuotasAntes, BigDecimal cuotaAntes, BigDecimal interesAntes,
                                BigDecimal totalAntes,
                                int cuotasDespues, BigDecimal cuotaDespues,
                                BigDecimal interesDespues, BigDecimal totalDespues,
                                BigDecimal ahorroInteres, int cuotasAhorradas,
                                BigDecimal ahorroNeto, BigDecimal rendimiento,
                                LocalDate desdeCuando) {

        public static SimulacionDto de(ServicioCreditos.SimulacionAbono s) {
            return new SimulacionDto(s.abono(), s.modo().name(),
                    s.cuotasAntes(), s.cuotaAntes(), s.interesAntes(), s.totalAntes(),
                    s.cuotasDespues(), s.cuotaDespues(), s.interesDespues(), s.totalDespues(),
                    s.ahorroInteres(), s.cuotasAhorradas(), s.ahorroNeto(), s.rendimiento(),
                    s.desdeCuando());
        }
    }
}
