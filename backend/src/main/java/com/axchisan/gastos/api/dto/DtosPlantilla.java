package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.PlantillaGasto;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.util.UUID;

/** Datos de entrada y salida de las plantillas de gastos fijos. */
public final class DtosPlantilla {

    private DtosPlantilla() {
    }

    public record PlantillaDto(UUID id, String nombre, CategoriaGasto categoria,
                               BigDecimal montoDefault, Short diaVencimiento, boolean activo,
                               short orden) {

        public static PlantillaDto de(PlantillaGasto plantilla) {
            return new PlantillaDto(plantilla.getId(), plantilla.getNombre(),
                    plantilla.getCategoria(), plantilla.getMontoDefault(),
                    plantilla.getDiaVencimiento(), plantilla.isActivo(), plantilla.getOrden());
        }
    }

    public record CrearPlantillaRequest(

            @NotBlank(message = "El nombre es obligatorio")
            String nombre,

            @NotNull(message = "La categoría es obligatoria")
            CategoriaGasto categoria,

            @NotNull(message = "El monto es obligatorio")
            @PositiveOrZero(message = "El monto no puede ser negativo")
            BigDecimal montoDefault,

            @Min(value = 1, message = "El día de vencimiento debe estar entre 1 y 31")
            @Max(value = 31, message = "El día de vencimiento debe estar entre 1 y 31")
            Short diaVencimiento,

            Short orden) {
    }

    public record ActualizarPlantillaRequest(
            String nombre,
            CategoriaGasto categoria,
            @PositiveOrZero(message = "El monto no puede ser negativo") BigDecimal montoDefault,
            @Min(1) @Max(31) Short diaVencimiento,
            Boolean activo,
            Short orden) {
    }
}
