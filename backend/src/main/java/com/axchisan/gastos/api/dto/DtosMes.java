package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.MesPresupuestal;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.UUID;

/** Datos de entrada y salida del mes presupuestal. */
public final class DtosMes {

    private DtosMes() {
    }

    /** Vista resumida de un mes, sin sus gastos. */
    public record MesDto(UUID id, int anio, int mes, YearMonth periodo, BigDecimal ingresoBase,
                         boolean cerrado, String notas) {

        public static MesDto de(MesPresupuestal mes) {
            return new MesDto(mes.getId(), mes.getAnio(), mes.getMes(), mes.periodo(),
                    mes.getIngresoBase(), mes.isCerrado(), mes.getNotas());
        }
    }

    /**
     * Alta de un mes.
     *
     * <p>Si no se indican el sueldo o la tarifa del pasaje, se heredan del último mes registrado.
     */
    public record CrearMesRequest(

            @NotNull(message = "El año es obligatorio")
            @Min(value = 2000, message = "El año debe ser posterior al 2000")
            @Max(value = 2100, message = "El año debe ser anterior al 2100")
            Integer anio,

            @NotNull(message = "El mes es obligatorio")
            @Min(value = 1, message = "El mes debe estar entre 1 y 12")
            @Max(value = 12, message = "El mes debe estar entre 1 y 12")
            Integer mes,

            @PositiveOrZero(message = "El sueldo no puede ser negativo")
            BigDecimal ingresoBase,

            @PositiveOrZero(message = "El valor del pasaje no puede ser negativo")
            BigDecimal valorPasaje) {

        public YearMonth periodo() {
            return YearMonth.of(anio, mes);
        }
    }

    public record ActualizarMesRequest(
            @PositiveOrZero(message = "El sueldo no puede ser negativo")
            BigDecimal ingresoBase,
            String notas) {
    }

    /** Ingreso adicional al sueldo. */
    public record CrearIngresoRequest(
            @NotNull(message = "El concepto es obligatorio") String concepto,
            @NotNull(message = "El monto es obligatorio") BigDecimal monto,
            java.time.LocalDate fecha,
            Boolean recibido) {
    }

    public record IngresoDto(UUID id, String concepto, BigDecimal monto,
                             java.time.LocalDate fecha, boolean recibido) {

        public static IngresoDto de(com.axchisan.gastos.dominio.Ingreso ingreso) {
            return new IngresoDto(ingreso.getId(), ingreso.getConcepto(), ingreso.getMonto(),
                    ingreso.getFecha(), ingreso.isRecibido());
        }
    }
}
