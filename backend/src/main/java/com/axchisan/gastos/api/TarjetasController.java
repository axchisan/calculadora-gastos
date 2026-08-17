package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosCompra.ActualizarTarjetaRequest;
import com.axchisan.gastos.api.dto.DtosCompra.AliasDto;
import com.axchisan.gastos.api.dto.DtosCompra.AnadirAliasRequest;
import com.axchisan.gastos.api.dto.DtosCompra.CrearTarjetaRequest;
import com.axchisan.gastos.api.dto.DtosCompra.TarjetaDto;
import com.axchisan.gastos.dominio.AliasTarjeta;
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
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/tarjetas")
@Tag(name = "Tarjetas", description = "Tarjetas de débito y crédito con su ciclo de facturación")
public class TarjetasController {

    private final ServicioTarjetas tarjetas;

    public TarjetasController(ServicioTarjetas tarjetas) {
        this.tarjetas = tarjetas;
    }

    @GetMapping
    @Operation(summary = "Lista las tarjetas con sus alias de reconocimiento")
    public List<TarjetaDto> listar() {
        UUID usuarioId = UsuarioActual.id();

        // Los alias se traen de una vez y se reparten en memoria: son un puñado de filas y
        // pedirlos tarjeta por tarjeta multiplicaría las consultas sin ganar nada.
        Map<UUID, List<AliasTarjeta>> porTarjeta = tarjetas.todosLosAlias(usuarioId).stream()
                .collect(Collectors.groupingBy(a -> a.getTarjeta().getId()));

        return tarjetas.listar(usuarioId).stream()
                .map(t -> TarjetaDto.de(t, porTarjeta.getOrDefault(t.getId(), List.of())))
                .toList();
    }

    @PostMapping("/{tarjetaId}/alias")
    @Operation(summary = "Enseña a reconocer la tarjeta en las notificaciones de pago")
    public ResponseEntity<AliasDto> anadirAlias(@PathVariable UUID tarjetaId,
                                                @Valid @RequestBody AnadirAliasRequest peticion) {
        var alias = tarjetas.anadirAlias(UsuarioActual.id(), tarjetaId, peticion.apodo(),
                peticion.ultimos4());
        return ResponseEntity.status(HttpStatus.CREATED).body(AliasDto.de(alias));
    }

    @DeleteMapping("/alias/{aliasId}")
    @Operation(summary = "Deja de reconocer la tarjeta por ese apodo o esos dígitos")
    public ResponseEntity<Void> eliminarAlias(@PathVariable UUID aliasId) {
        tarjetas.eliminarAlias(UsuarioActual.id(), aliasId);
        return ResponseEntity.noContent().build();
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
