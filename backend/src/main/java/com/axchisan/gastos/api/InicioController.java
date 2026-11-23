package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosCuenta.CuentaDto;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ResumenMensual;
import com.axchisan.gastos.servicio.ServicioInicio;
import com.axchisan.gastos.servicio.ServicioInicio.ProximoPago;
import com.axchisan.gastos.servicio.ServicioSueldo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

@RestController
@RequestMapping("/api/inicio")
@Tag(name = "Inicio", description = "Todo lo de la pantalla de inicio en una sola petición")
public class InicioController {

    private final ServicioInicio inicio;

    public InicioController(ServicioInicio inicio) {
        this.inicio = inicio;
    }

    /**
     * @param resumen       resumen del mes en curso; ausente si ese mes aún no existe
     * @param proximosPagos lo vencido, lo pendiente del mes sin día fijo y lo que vence en los
     *                      próximos treinta días, en ese orden
     */
    public record InicioDto(LocalDate hoy, YearMonth periodo, ResumenMensual resumen,
                            List<CuentaDto> cuentas, List<ProximoPago> proximosPagos) {
    }

    @GetMapping
    @Operation(summary = "Resumen del mes en curso, cuentas y próximos pagos")
    public InicioDto obtener(
            // Solo para ver cómo se veía otro día; la app nunca lo envía.
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate fecha) {
        var datos = inicio.de(UsuarioActual.id(), fecha != null ? fecha : ServicioSueldo.hoy());
        return new InicioDto(datos.hoy(), datos.periodo(), datos.resumen(),
                datos.cuentas().stream().map(CuentaDto::de).toList(), datos.proximosPagos());
    }
}
