package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.EstadoGasto;
import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.OrigenGasto;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/** Datos de entrada y salida de los gastos. */
public final class DtosGasto {

    private DtosGasto() {
    }

    /**
     * Gasto del mes.
     *
     * @param editable indica si admite edición directa; los generados por el sistema
     *                 (transporte, deudas) se modifican desde su propio módulo
     */
    public record GastoDto(UUID id, String nombre, CategoriaGasto categoria, BigDecimal monto,
                           BigDecimal montoPagado, BigDecimal saldoPendiente, EstadoGasto estado,
                           LocalDate fechaPago, Short diaVencimiento, OrigenGasto origen,
                           boolean editable, String notas, short orden) {

        public static GastoDto de(Gasto gasto) {
            return new GastoDto(
                    gasto.getId(), gasto.getNombre(), gasto.getCategoria(), gasto.getMonto(),
                    gasto.getMontoPagado(), gasto.saldoPendiente(), gasto.getEstado(),
                    gasto.getFechaPago(), gasto.getDiaVencimiento(), gasto.getOrigen(),
                    !gasto.getOrigen().esGeneradoPorElSistema(), gasto.getNotas(),
                    gasto.getOrden());
        }
    }

    public record CrearGastoRequest(

            @NotBlank(message = "El nombre es obligatorio")
            String nombre,

            @NotNull(message = "La categoría es obligatoria")
            CategoriaGasto categoria,

            @NotNull(message = "El monto es obligatorio")
            @PositiveOrZero(message = "El monto no puede ser negativo")
            BigDecimal monto,

            @Min(value = 1, message = "El día de vencimiento debe estar entre 1 y 31")
            @Max(value = 31, message = "El día de vencimiento debe estar entre 1 y 31")
            Short diaVencimiento,

            String notas) {
    }

    public record ActualizarGastoRequest(
            String nombre,
            CategoriaGasto categoria,
            @PositiveOrZero(message = "El monto no puede ser negativo") BigDecimal monto,
            @Min(1) @Max(31) Short diaVencimiento,
            String notas) {
    }

    /** Abono parcial a un gasto. */
    public record AbonarRequest(
            @NotNull(message = "El importe es obligatorio")
            @Positive(message = "El importe debe ser mayor que cero")
            BigDecimal importe,
            LocalDate fecha) {
    }

    public record MarcarPagadoRequest(LocalDate fecha) {
    }
}
