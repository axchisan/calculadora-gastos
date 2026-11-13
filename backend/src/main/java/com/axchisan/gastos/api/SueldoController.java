package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosSueldo.ActualizarFuenteRequest;
import com.axchisan.gastos.api.dto.DtosSueldo.CrearFuenteRequest;
import com.axchisan.gastos.api.dto.DtosSueldo.FuenteDto;
import com.axchisan.gastos.api.dto.DtosSueldo.MesAplicadoDto;
import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioSueldo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/sueldo")
@Tag(name = "Sueldo", description = "Ingresos en otra moneda y sus pagos esperados en pesos")
public class SueldoController {

    /** Pagos que se adjuntan a cada fuente al listarlas. */
    private static final int PAGOS_EN_LISTADO = 4;

    private final ServicioSueldo sueldo;

    public SueldoController(ServicioSueldo sueldo) {
        this.sueldo = sueldo;
    }

    @GetMapping
    @Operation(summary = "Lista los ingresos en otra moneda con sus próximos pagos")
    public List<FuenteDto> listar() {
        UUID usuarioId = UsuarioActual.id();
        return sueldo.listar(usuarioId).stream().map(f -> conPagos(usuarioId, f)).toList();
    }

    @PostMapping
    @Operation(summary = "Registra un ingreso en otra moneda")
    public ResponseEntity<FuenteDto> crear(@Valid @RequestBody CrearFuenteRequest peticion) {
        UUID usuarioId = UsuarioActual.id();
        FuenteIngreso fuente = sueldo.crear(usuarioId, peticion.comoCambios());
        return ResponseEntity.status(HttpStatus.CREATED).body(conPagos(usuarioId, fuente));
    }

    @PatchMapping("/{fuenteId}")
    @Operation(summary = "Modifica las condiciones, la TRM o los costos de cobro")
    public FuenteDto actualizar(@PathVariable UUID fuenteId,
                                @Valid @RequestBody ActualizarFuenteRequest peticion) {
        UUID usuarioId = UsuarioActual.id();
        return conPagos(usuarioId, sueldo.actualizar(usuarioId, fuenteId, peticion.comoCambios()));
    }

    @DeleteMapping("/{fuenteId}")
    @Operation(summary = "Elimina un ingreso en otra moneda")
    public ResponseEntity<Void> eliminar(@PathVariable UUID fuenteId) {
        sueldo.eliminar(UsuarioActual.id(), fuenteId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{fuenteId}/proyeccion")
    @Operation(summary = "Los próximos pagos, con el periodo que cubren y su valor en pesos")
    public List<com.axchisan.gastos.api.dto.DtosSueldo.PagoDto> proyeccion(
            @PathVariable UUID fuenteId,
            @RequestParam(required = false) YearMonth desde,
            @RequestParam(defaultValue = "6") int pagos) {
        return sueldo.proyeccion(UsuarioActual.id(), fuenteId, desde, pagos).stream()
                .map(com.axchisan.gastos.api.dto.DtosSueldo.PagoDto::de)
                .toList();
    }

    @PostMapping("/{fuenteId}/llevar-al-presupuesto")
    @Operation(summary = "Pone cada pago proyectado como sueldo base de su mes")
    public List<MesAplicadoDto> llevarAlPresupuesto(
            @PathVariable UUID fuenteId,
            @RequestParam(required = false) YearMonth desde,
            @RequestParam(defaultValue = "3") int pagos) {
        return sueldo.llevarAlPresupuesto(UsuarioActual.id(), fuenteId, desde, pagos)
                .entrySet().stream()
                .map(e -> new MesAplicadoDto(e.getKey().toString(), e.getValue()))
                .toList();
    }

    private FuenteDto conPagos(UUID usuarioId, FuenteIngreso fuente) {
        return FuenteDto.de(fuente,
                sueldo.proyeccion(usuarioId, fuente.getId(), null, PAGOS_EN_LISTADO));
    }
}
