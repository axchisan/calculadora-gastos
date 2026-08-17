package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.AbonoDeuda;
import com.axchisan.gastos.dominio.Deuda;
import com.axchisan.gastos.dominio.TipoDeuda;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.UUID;

/** Datos de entrada y salida de las deudas externas. */
public final class DtosDeuda {

    private DtosDeuda() {
    }

    public record DeudaDto(UUID id, String acreedor, String descripcion, TipoDeuda tipo,
                           BigDecimal montoOriginal, BigDecimal saldo, BigDecimal porcentajePagado,
                           BigDecimal tasaInteresMensual, BigDecimal interesMensualEstimado,
                           BigDecimal cuotaSugerida, LocalDate fechaInicio, LocalDate fechaLimite,
                           boolean activa) {

        public static DeudaDto de(Deuda deuda) {
            return new DeudaDto(
                    deuda.getId(), deuda.getAcreedor(), deuda.getDescripcion(), deuda.getTipo(),
                    deuda.getMontoOriginal(), deuda.getSaldo(), deuda.porcentajePagado(),
                    deuda.getTasaInteresMensual(), deuda.interesMensualEstimado(),
                    deuda.getCuotaSugerida(), deuda.getFechaInicio(), deuda.getFechaLimite(),
                    deuda.isActiva());
        }

        /**
         * La deuda tal y como estaba al cerrar un mes pasado.
         *
         * <p>Al consultar agosto interesa lo que se debía en agosto. Mostrar el saldo de hoy
         * haría que una deuda saldada apareciera en cero en el mes en que aún se debía entera.
         */
        public static DeudaDto deEnPeriodo(Deuda deuda, BigDecimal saldoDelPeriodo) {
            BigDecimal original = deuda.getMontoOriginal();
            BigDecimal porcentaje = original.signum() == 0
                    ? BigDecimal.valueOf(100)
                    : original.subtract(saldoDelPeriodo)
                            .multiply(BigDecimal.valueOf(100))
                            .divide(original, 2, RoundingMode.HALF_UP);

            return new DeudaDto(
                    deuda.getId(), deuda.getAcreedor(), deuda.getDescripcion(), deuda.getTipo(),
                    original, saldoDelPeriodo, porcentaje,
                    deuda.getTasaInteresMensual(), deuda.interesMensualEstimado(),
                    deuda.getCuotaSugerida(), deuda.getFechaInicio(), deuda.getFechaLimite(),
                    saldoDelPeriodo.signum() > 0);
        }
    }

    public record CrearDeudaRequest(

            @NotBlank(message = "El acreedor es obligatorio")
            String acreedor,

            @NotNull(message = "El tipo de deuda es obligatorio")
            TipoDeuda tipo,

            @NotNull(message = "El monto es obligatorio")
            @Positive(message = "El monto debe ser mayor que cero")
            BigDecimal montoOriginal,

            LocalDate fechaInicio,
            String descripcion,

            @PositiveOrZero(message = "La tasa de interés no puede ser negativa")
            BigDecimal tasaInteresMensual,

            @PositiveOrZero(message = "La cuota no puede ser negativa")
            BigDecimal cuotaSugerida,

            LocalDate fechaLimite) {
    }

    /**
     * Cambios sobre una deuda.
     *
     * <p>Corregir {@code montoOriginal} conserva lo ya abonado y recalcula el saldo, de modo que
     * arreglar un importe mal apuntado no borra el historial de pagos.
     */
    public record ActualizarDeudaRequest(
            String acreedor,
            TipoDeuda tipo,
            String descripcion,
            @PositiveOrZero BigDecimal tasaInteresMensual,
            @PositiveOrZero BigDecimal cuotaSugerida,
            LocalDate fechaLimite,
            @Positive(message = "El monto debe ser mayor que cero")
            BigDecimal montoOriginal) {
    }

    /** Abono a una deuda. El mes es opcional: sirve para imputarlo al presupuesto. */
    public record AbonarDeudaRequest(

            @NotNull(message = "El monto es obligatorio")
            @Positive(message = "El monto debe ser mayor que cero")
            BigDecimal monto,

            LocalDate fecha,
            UUID mesId,
            String nota) {
    }

    public record AbonoDto(UUID id, UUID deudaId, UUID mesId, BigDecimal monto, LocalDate fecha,
                           String nota) {

        public static AbonoDto de(AbonoDeuda abono) {
            return new AbonoDto(abono.getId(), abono.getDeuda().getId(),
                    abono.getMes() == null ? null : abono.getMes().getId(),
                    abono.getMonto(), abono.getFecha(), abono.getNota());
        }
    }
}
