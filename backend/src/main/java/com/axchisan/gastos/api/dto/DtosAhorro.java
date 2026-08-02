package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.MetaAhorro;
import com.axchisan.gastos.dominio.MovimientoAhorro;
import com.axchisan.gastos.dominio.TipoAsignacion;
import com.axchisan.gastos.dominio.TipoMovimientoAhorro;
import com.axchisan.gastos.servicio.ServicioAhorro;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/** Datos de entrada y salida de las metas de ahorro. */
public final class DtosAhorro {

    private DtosAhorro() {
    }

    public record MetaDto(UUID id, String nombre, TipoAsignacion tipoAsignacion, BigDecimal valor,
                          BigDecimal metaMonto, BigDecimal saldoAcumulado,
                          BigDecimal porcentajeAlcanzado, String color, short prioridad,
                          boolean activa) {

        public static MetaDto de(MetaAhorro meta) {
            return new MetaDto(meta.getId(), meta.getNombre(), meta.getTipoAsignacion(),
                    meta.getValor(), meta.getMetaMonto(), meta.getSaldoAcumulado(),
                    meta.porcentajeAlcanzado(), meta.getColor(), meta.getPrioridad(),
                    meta.isActiva());
        }
    }

    public record CrearMetaRequest(

            @NotBlank(message = "El nombre es obligatorio")
            String nombre,

            @NotNull(message = "El tipo de asignación es obligatorio")
            TipoAsignacion tipoAsignacion,

            @NotNull(message = "El valor es obligatorio")
            @PositiveOrZero(message = "El valor no puede ser negativo")
            BigDecimal valor,

            @Positive(message = "El objetivo debe ser mayor que cero")
            BigDecimal metaMonto,

            String color,
            Short prioridad) {
    }

    public record ActualizarMetaRequest(
            String nombre,
            TipoAsignacion tipoAsignacion,
            @PositiveOrZero BigDecimal valor,
            @Positive BigDecimal metaMonto,
            String color,
            Short prioridad,
            Boolean activa) {
    }

    public record MovimientoRequest(

            @NotNull(message = "El tipo de movimiento es obligatorio")
            TipoMovimientoAhorro tipo,

            @NotNull(message = "El monto es obligatorio")
            @Positive(message = "El monto debe ser mayor que cero")
            BigDecimal monto,

            LocalDate fecha,
            UUID mesId,
            String nota) {
    }

    public record MovimientoDto(UUID id, UUID metaId, UUID mesId, TipoMovimientoAhorro tipo,
                                BigDecimal monto, LocalDate fecha, String nota) {

        public static MovimientoDto de(MovimientoAhorro movimiento) {
            return new MovimientoDto(movimiento.getId(), movimiento.getMeta().getId(),
                    movimiento.getMes() == null ? null : movimiento.getMes().getId(),
                    movimiento.getTipo(), movimiento.getMonto(), movimiento.getFecha(),
                    movimiento.getNota());
        }
    }

    /** Reparto propuesto del dinero disponible entre las metas activas. */
    public record AsignacionDto(UUID metaId, String nombre, TipoAsignacion tipoAsignacion,
                                BigDecimal monto, String color) {

        public static AsignacionDto de(ServicioAhorro.Asignacion asignacion) {
            MetaAhorro meta = asignacion.meta();
            return new AsignacionDto(meta.getId(), meta.getNombre(), meta.getTipoAsignacion(),
                    asignacion.monto(), meta.getColor());
        }
    }
}
