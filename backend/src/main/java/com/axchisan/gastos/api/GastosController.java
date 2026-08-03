package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosGasto.AbonarRequest;
import com.axchisan.gastos.api.dto.DtosGasto.ActualizarGastoRequest;
import com.axchisan.gastos.api.dto.DtosGasto.CorregirPagoRequest;
import com.axchisan.gastos.api.dto.DtosGasto.CrearGastoRequest;
import com.axchisan.gastos.api.dto.DtosGasto.GastoDto;
import com.axchisan.gastos.api.dto.DtosGasto.MarcarPagadoRequest;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioGastos;
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
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@Tag(name = "Gastos", description = "Gastos del mes y control de pagos")
public class GastosController {

    private final ServicioGastos gastos;

    public GastosController(ServicioGastos gastos) {
        this.gastos = gastos;
    }

    @GetMapping("/api/meses/{mesId}/gastos")
    @Operation(summary = "Lista los gastos del mes")
    public List<GastoDto> listar(@PathVariable UUID mesId) {
        return gastos.listar(UsuarioActual.id(), mesId).stream().map(GastoDto::de).toList();
    }

    @PostMapping("/api/meses/{mesId}/gastos")
    @Operation(summary = "Añade un gasto puntual al mes")
    public ResponseEntity<GastoDto> crear(@PathVariable UUID mesId,
                                          @Valid @RequestBody CrearGastoRequest peticion) {
        var gasto = gastos.crear(UsuarioActual.id(), mesId, peticion.nombre(), peticion.categoria(),
                peticion.monto(), peticion.diaVencimiento(), peticion.notas());
        return ResponseEntity.status(HttpStatus.CREATED).body(GastoDto.de(gasto));
    }

    @PatchMapping("/api/gastos/{gastoId}")
    @Operation(summary = "Modifica un gasto")
    public GastoDto actualizar(@PathVariable UUID gastoId,
                               @Valid @RequestBody ActualizarGastoRequest peticion) {
        return GastoDto.de(gastos.actualizar(UsuarioActual.id(), gastoId, peticion.nombre(),
                peticion.categoria(), peticion.monto(), peticion.diaVencimiento(),
                peticion.notas()));
    }

    @PostMapping("/api/gastos/{gastoId}/pagar")
    @Operation(summary = "Marca el gasto como pagado por completo")
    public GastoDto pagar(@PathVariable UUID gastoId,
                          @RequestBody(required = false) MarcarPagadoRequest peticion) {
        return GastoDto.de(gastos.marcarPagado(UsuarioActual.id(), gastoId,
                peticion == null ? null : peticion.fecha()));
    }

    @PostMapping("/api/gastos/{gastoId}/pendiente")
    @Operation(summary = "Deshace el pago y devuelve el gasto a pendiente")
    public GastoDto marcarPendiente(@PathVariable UUID gastoId) {
        return GastoDto.de(gastos.marcarPendiente(UsuarioActual.id(), gastoId));
    }

    @PostMapping("/api/gastos/{gastoId}/corregir-pago")
    @Operation(summary = "Corrige cuánto se lleva pagado. Con cero, el gasto vuelve a estar "
            + "pendiente")
    public GastoDto corregirPago(@PathVariable UUID gastoId,
                                 @Valid @RequestBody CorregirPagoRequest peticion) {
        return GastoDto.de(gastos.corregirPago(UsuarioActual.id(), gastoId,
                peticion.montoPagado(), peticion.fecha()));
    }

    @PostMapping("/api/gastos/{gastoId}/abonar")
    @Operation(summary = "Registra un abono parcial")
    public GastoDto abonar(@PathVariable UUID gastoId, @Valid @RequestBody AbonarRequest peticion) {
        return GastoDto.de(gastos.abonar(UsuarioActual.id(), gastoId, peticion.importe(),
                peticion.fecha()));
    }

    @DeleteMapping("/api/gastos/{gastoId}")
    @Operation(summary = "Elimina un gasto")
    public ResponseEntity<Void> eliminar(@PathVariable UUID gastoId) {
        gastos.eliminar(UsuarioActual.id(), gastoId);
        return ResponseEntity.noContent().build();
    }
}
