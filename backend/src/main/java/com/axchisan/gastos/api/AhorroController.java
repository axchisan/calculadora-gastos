package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosAhorro.ActualizarMetaRequest;
import com.axchisan.gastos.api.dto.DtosAhorro.AsignacionDto;
import com.axchisan.gastos.api.dto.DtosAhorro.CrearMetaRequest;
import com.axchisan.gastos.api.dto.DtosAhorro.MetaDto;
import com.axchisan.gastos.api.dto.DtosAhorro.MovimientoDto;
import com.axchisan.gastos.api.dto.DtosAhorro.MovimientoRequest;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ResumenMensual;
import com.axchisan.gastos.servicio.ServicioAhorro;
import com.axchisan.gastos.servicio.ServicioResumen;
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
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/ahorro")
@Tag(name = "Ahorro", description = "Metas de ahorro y reparto del dinero disponible")
public class AhorroController {

    private final ServicioAhorro ahorro;
    private final ServicioResumen resumen;

    public AhorroController(ServicioAhorro ahorro, ServicioResumen resumen) {
        this.ahorro = ahorro;
        this.resumen = resumen;
    }

    @GetMapping("/metas")
    @Operation(summary = "Lista las metas de ahorro")
    public List<MetaDto> listar() {
        return ahorro.listar(UsuarioActual.id()).stream().map(MetaDto::de).toList();
    }

    @PostMapping("/metas")
    @Operation(summary = "Crea una meta de ahorro")
    public ResponseEntity<MetaDto> crear(@Valid @RequestBody CrearMetaRequest peticion) {
        var meta = ahorro.crear(UsuarioActual.id(), peticion.nombre(), peticion.tipoAsignacion(),
                peticion.valor(), peticion.metaMonto(), peticion.color(), peticion.prioridad());
        return ResponseEntity.status(HttpStatus.CREATED).body(MetaDto.de(meta));
    }

    @PatchMapping("/metas/{metaId}")
    @Operation(summary = "Modifica una meta de ahorro")
    public MetaDto actualizar(@PathVariable UUID metaId,
                              @Valid @RequestBody ActualizarMetaRequest peticion) {
        return MetaDto.de(ahorro.actualizar(UsuarioActual.id(), metaId, peticion.nombre(),
                peticion.tipoAsignacion(), peticion.valor(), peticion.metaMonto(),
                peticion.color(), peticion.prioridad(), peticion.activa()));
    }

    @GetMapping("/metas/{metaId}/movimientos")
    @Operation(summary = "Historial de aportes y retiros de la meta")
    public List<MovimientoDto> movimientos(@PathVariable UUID metaId) {
        return ahorro.movimientosDe(UsuarioActual.id(), metaId).stream()
                .map(MovimientoDto::de).toList();
    }

    @PostMapping("/metas/{metaId}/movimientos")
    @Operation(summary = "Registra un aporte o un retiro")
    public ResponseEntity<MovimientoDto> registrarMovimiento(
            @PathVariable UUID metaId, @Valid @RequestBody MovimientoRequest peticion) {
        var movimiento = ahorro.registrarMovimiento(UsuarioActual.id(), metaId, peticion.tipo(),
                peticion.monto(), peticion.fecha(), peticion.mesId(), peticion.nota());
        return ResponseEntity.status(HttpStatus.CREATED).body(MovimientoDto.de(movimiento));
    }

    @DeleteMapping("/movimientos/{movimientoId}")
    @Operation(summary = "Elimina un movimiento y revierte el saldo")
    public ResponseEntity<Void> eliminarMovimiento(@PathVariable UUID movimientoId) {
        ahorro.eliminarMovimiento(UsuarioActual.id(), movimientoId);
        return ResponseEntity.noContent().build();
    }

    /**
     * Propone cómo repartir el dinero que queda en un mes.
     *
     * <p>Es una sugerencia: no mueve dinero. Para materializarla hay que registrar los
     * movimientos correspondientes.
     */
    @GetMapping("/distribucion/{mesId}")
    @Operation(summary = "Sugiere el reparto del disponible entre las metas activas")
    public List<AsignacionDto> sugerirDistribucion(@PathVariable UUID mesId) {
        UUID usuarioId = UsuarioActual.id();
        ResumenMensual mes = resumen.del(usuarioId, mesId);
        return ahorro.sugerirDistribucion(usuarioId, mes.ingresoTotal(), mes.saldoProyectado())
                .stream().map(AsignacionDto::de).toList();
    }

    @DeleteMapping("/metas/{metaId}")
    @Operation(summary = "Elimina una meta y su historial")
    public ResponseEntity<Void> eliminar(@PathVariable UUID metaId) {
        ahorro.eliminar(UsuarioActual.id(), metaId);
        return ResponseEntity.noContent().build();
    }
}
