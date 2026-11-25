package com.axchisan.gastos.api;

import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioPlan;
import com.axchisan.gastos.servicio.ServicioPlan.Plan;
import com.axchisan.gastos.servicio.ServicioSueldo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.PositiveOrZero;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/plan")
@Tag(name = "Plan", description = "Cuánto sobra del sueldo cada mes y cuándo se alcanzan las metas")
public class PlanController {

    private final ServicioPlan plan;

    public PlanController(ServicioPlan plan) {
        this.plan = plan;
    }

    /** @param gastoDiario el gasto del día a día al mes; null vuelve a la estimación */
    public record AjustesRequest(@PositiveOrZero BigDecimal gastoDiario) {
    }

    @GetMapping
    @Operation(summary = "Lo que entra, lo que sale y lo que sobra mes a mes, con las metas")
    public Plan ver(@RequestParam(defaultValue = "12") int meses,
                    @RequestParam(required = false)
                    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha) {
        return plan.de(UsuarioActual.id(), fecha != null ? fecha : ServicioSueldo.hoy(), meses);
    }

    @PatchMapping("/ajustes")
    @Operation(summary = "Fija el gasto del día a día (null para que lo estime la app)")
    public Plan ajustar(@Valid @RequestBody AjustesRequest peticion) {
        plan.fijarGastoDiario(UsuarioActual.id(), peticion.gastoDiario());
        return plan.de(UsuarioActual.id(), ServicioSueldo.hoy(), ServicioPlan.MESES_POR_DEFECTO);
    }
}
