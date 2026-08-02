package com.axchisan.gastos.api;

import com.axchisan.gastos.calendario.CalculadoraFestivos;
import com.axchisan.gastos.calendario.Festivo;
import com.axchisan.gastos.calendario.TipoFestivo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

/** Festivos de Colombia, calculados según la Ley 51 de 1983. */
@RestController
@RequestMapping("/api/festivos")
@Tag(name = "Festivos", description = "Calendario de festivos colombianos")
public class FestivosController {

    private final CalculadoraFestivos festivos;

    public FestivosController(CalculadoraFestivos festivos) {
        this.festivos = festivos;
    }

    /**
     * @param fecha         día en que se celebra
     * @param diaSemana     día de la semana resultante
     * @param nombre        nombre del festivo
     * @param tipo          cómo se determinó la fecha
     * @param fechaOriginal fecha antes del traslado de la Ley Emiliani
     * @param trasladado    si la Ley Emiliani lo movió
     */
    public record FestivoDto(LocalDate fecha, DayOfWeek diaSemana, String nombre, TipoFestivo tipo,
                             LocalDate fechaOriginal, boolean trasladado) {

        static FestivoDto de(Festivo festivo) {
            return new FestivoDto(festivo.fecha(), festivo.fecha().getDayOfWeek(),
                    festivo.nombre(), festivo.tipo(), festivo.fechaOriginal(),
                    festivo.fueTrasladado());
        }
    }

    @GetMapping("/{anio}")
    @Operation(summary = "Festivos del año. Son 18 celebraciones, que pueden ocupar 17 días "
            + "cuando dos coinciden en la misma fecha")
    public List<FestivoDto> delAnio(@PathVariable int anio) {
        return festivos.delAnio(anio).stream().map(FestivoDto::de).toList();
    }

    @GetMapping("/{anio}/{mes}")
    @Operation(summary = "Festivos de un mes concreto")
    public List<FestivoDto> delMes(@PathVariable int anio, @PathVariable int mes) {
        return festivos.delMes(YearMonth.of(anio, mes)).stream().map(FestivoDto::de).toList();
    }
}
