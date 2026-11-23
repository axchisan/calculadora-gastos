package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosDeuda.AbonarDeudaRequest;
import com.axchisan.gastos.api.dto.DtosDeuda.AbonoDto;
import com.axchisan.gastos.api.dto.DtosDeuda.ActualizarDeudaRequest;
import com.axchisan.gastos.api.dto.DtosDeuda.CrearDeudaRequest;
import com.axchisan.gastos.api.dto.DtosDeuda.DeudaDto;
import com.axchisan.gastos.dominio.Deuda;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioDeudas;
import com.axchisan.gastos.servicio.ServicioPanoramaDeudas;
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
@RequestMapping("/api/deudas")
@Tag(name = "Deudas", description = "Deudas externas y sus abonos")
public class DeudasController {

    private final ServicioDeudas deudas;
    private final ServicioPanoramaDeudas panorama;

    public DeudasController(ServicioDeudas deudas, ServicioPanoramaDeudas panorama) {
        this.deudas = deudas;
        this.panorama = panorama;
    }

    @GetMapping("/panorama")
    @Operation(summary = "Todo lo que se debe (créditos y deudas) y cómo baja mes a mes")
    public ServicioPanoramaDeudas.Panorama panorama(
            // Solo para ver cómo se veía otro día; la app nunca lo envía.
            @RequestParam(required = false)
            @org.springframework.format.annotation.DateTimeFormat(
                    iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE)
            java.time.LocalDate fecha) {
        return panorama.de(UsuarioActual.id(), fecha != null ? fecha : ServicioSueldo.hoy());
    }

    /**
     * Lista las deudas.
     *
     * <p>Con {@code periodo} se obtienen solo las que tenían algo que ver con ese mes: las que
     * seguían debiéndose al terminarlo y las que se saldaron durante él. Sin ese filtro, las
     * deudas pagadas en agosto seguían apareciendo en septiembre y en todos los meses
     * siguientes, donde ya no significan nada.
     */
    @GetMapping
    @Operation(summary = "Lista las deudas; con 'periodo' (aaaa-mm), solo las de ese mes")
    public List<DeudaDto> listar(@RequestParam(defaultValue = "false") boolean soloActivas,
                                 @RequestParam(required = false) YearMonth periodo) {
        UUID usuarioId = UsuarioActual.id();

        List<Deuda> lista;
        if (periodo != null) {
            lista = deudas.listarDelPeriodo(usuarioId, periodo);
        } else if (soloActivas) {
            lista = deudas.listarActivas(usuarioId);
        } else {
            lista = deudas.listar(usuarioId);
        }

        // Al mirar un mes pasado interesa el saldo que la deuda tenía entonces, no el de hoy.
        return lista.stream()
                .map(deuda -> periodo == null
                        ? DeudaDto.de(deuda)
                        : DeudaDto.deEnPeriodo(deuda, deudas.saldoAlCierreDe(
                                deuda.getId(), deuda.getMontoOriginal(), periodo)))
                .toList();
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
