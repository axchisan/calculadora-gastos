package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosDeuda.AbonarDeudaRequest;
import com.axchisan.gastos.api.dto.DtosDeuda.AbonoDto;
import com.axchisan.gastos.api.dto.DtosDeuda.ActualizarDeudaRequest;
import com.axchisan.gastos.api.dto.DtosDeuda.CrearDeudaRequest;
import com.axchisan.gastos.api.dto.DtosDeuda.DeudaDto;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioDeudas;
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

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/deudas")
@Tag(name = "Deudas", description = "Deudas externas y sus abonos")
public class DeudasController {

    private final ServicioDeudas deudas;

    public DeudasController(ServicioDeudas deudas) {
        this.deudas = deudas;
    }

    @GetMapping
    @Operation(summary = "Lista las deudas; por defecto incluye las ya saldadas")
    public List<DeudaDto> listar(@RequestParam(defaultValue = "false") boolean soloActivas) {
        UUID usuarioId = UsuarioActual.id();
        var lista = soloActivas ? deudas.listarActivas(usuarioId) : deudas.listar(usuarioId);
        return lista.stream().map(DeudaDto::de).toList();
    }

    @GetMapping("/{deudaId}")
    @Operation(summary = "Devuelve una deuda")
    public DeudaDto obtener(@PathVariable UUID deudaId) {
        return DeudaDto.de(deudas.buscar(UsuarioActual.id(), deudaId));
    }

    @PostMapping
    @Operation(summary = "Registra una deuda")
    public ResponseEntity<DeudaDto> crear(@Valid @RequestBody CrearDeudaRequest peticion) {
        var deuda = deudas.crear(UsuarioActual.id(), peticion.acreedor(), peticion.tipo(),
                peticion.montoOriginal(), peticion.fechaInicio(), peticion.descripcion(),
                peticion.tasaInteresMensual(), peticion.cuotaSugerida(), peticion.fechaLimite());
        return ResponseEntity.status(HttpStatus.CREATED).body(DeudaDto.de(deuda));
    }

    @PatchMapping("/{deudaId}")
    @Operation(summary = "Modifica los datos de una deuda")
    public DeudaDto actualizar(@PathVariable UUID deudaId,
                               @Valid @RequestBody ActualizarDeudaRequest peticion) {
        return DeudaDto.de(deudas.actualizar(UsuarioActual.id(), deudaId, peticion.acreedor(),
                peticion.tipo(), peticion.descripcion(), peticion.tasaInteresMensual(),
                peticion.cuotaSugerida(), peticion.fechaLimite(), peticion.montoOriginal()));
    }

    @GetMapping("/{deudaId}/abonos")
    @Operation(summary = "Historial de abonos de la deuda")
    public List<AbonoDto> abonos(@PathVariable UUID deudaId) {
        return deudas.abonosDe(UsuarioActual.id(), deudaId).stream().map(AbonoDto::de).toList();
    }

    @PostMapping("/{deudaId}/abonos")
    @Operation(summary = "Registra un abono y descuenta el saldo")
    public ResponseEntity<AbonoDto> abonar(@PathVariable UUID deudaId,
                                           @Valid @RequestBody AbonarDeudaRequest peticion) {
        var abono = deudas.registrarAbono(UsuarioActual.id(), deudaId, peticion.monto(),
                peticion.fecha(), peticion.mesId(), peticion.nota());
        return ResponseEntity.status(HttpStatus.CREATED).body(AbonoDto.de(abono));
    }

    @DeleteMapping("/abonos/{abonoId}")
    @Operation(summary = "Elimina un abono y devuelve el importe al saldo")
    public ResponseEntity<Void> eliminarAbono(@PathVariable UUID abonoId) {
        deudas.eliminarAbono(UsuarioActual.id(), abonoId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{deudaId}")
    @Operation(summary = "Elimina la deuda y su historial de abonos")
    public ResponseEntity<Void> eliminar(@PathVariable UUID deudaId) {
        deudas.eliminar(UsuarioActual.id(), deudaId);
        return ResponseEntity.noContent().build();
    }
}
