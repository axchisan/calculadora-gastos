package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosCompra.ActualizarTarjetaRequest;
import com.axchisan.gastos.api.dto.DtosCompra.CrearTarjetaRequest;
import com.axchisan.gastos.api.dto.DtosCompra.TarjetaDto;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioTarjetas;
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
@RequestMapping("/api/tarjetas")
@Tag(name = "Tarjetas", description = "Tarjetas de débito y crédito con su ciclo de facturación")
public class TarjetasController {

    private final ServicioTarjetas tarjetas;

    public TarjetasController(ServicioTarjetas tarjetas) {
        this.tarjetas = tarjetas;
    }

    @GetMapping
    @Operation(summary = "Lista las tarjetas")
    public List<TarjetaDto> listar() {
        return tarjetas.listar(UsuarioActual.id()).stream().map(TarjetaDto::de).toList();
    }

    @PostMapping
    @Operation(summary = "Registra una tarjeta")
    public ResponseEntity<TarjetaDto> crear(@Valid @RequestBody CrearTarjetaRequest peticion) {
        var tarjeta = tarjetas.crear(UsuarioActual.id(), peticion.nombre(), peticion.tipo(),
                peticion.diaCorte(), peticion.diaPago(), peticion.color());
        return ResponseEntity.status(HttpStatus.CREATED).body(TarjetaDto.de(tarjeta));
    }

    @PatchMapping("/{tarjetaId}")
    @Operation(summary = "Modifica una tarjeta")
    public TarjetaDto actualizar(@PathVariable UUID tarjetaId,
                                 @Valid @RequestBody ActualizarTarjetaRequest peticion) {
        return TarjetaDto.de(tarjetas.actualizar(UsuarioActual.id(), tarjetaId, peticion.nombre(),
                peticion.diaCorte(), peticion.diaPago(), peticion.color(), peticion.activa()));
    }

    @DeleteMapping("/{tarjetaId}")
    @Operation(summary = "Elimina la tarjeta, o la archiva si ya tiene compras")
    public ResponseEntity<Void> eliminar(@PathVariable UUID tarjetaId) {
        tarjetas.eliminar(UsuarioActual.id(), tarjetaId);
        return ResponseEntity.noContent().build();
    }
}
