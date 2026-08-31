package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosCredito.CrearCreditoRequest;
import com.axchisan.gastos.api.dto.DtosCredito.CreditoDto;
import com.axchisan.gastos.api.dto.DtosCredito.CuotaDelPlan;
import com.axchisan.gastos.api.dto.DtosCredito.CuotaDto;
import com.axchisan.gastos.api.dto.DtosCredito.MarcarCuotaRequest;
import com.axchisan.gastos.api.dto.DtosCredito.SimulacionDto;
import com.axchisan.gastos.dominio.Credito;
import com.axchisan.gastos.dominio.CuotaCredito;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioCreditos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/creditos")
@Tag(name = "Créditos", description = "Créditos con cuadro de amortización")
public class CreditosController {

    private final ServicioCreditos creditos;

    public CreditosController(ServicioCreditos creditos) {
        this.creditos = creditos;
    }

    @GetMapping
    @Operation(summary = "Lista los créditos con su estado")
    public List<CreditoDto> listar() {
        UUID usuarioId = UsuarioActual.id();
        return creditos.listar(usuarioId).stream()
                .map(c -> CreditoDto.de(creditos.estadoDe(usuarioId, c.getId())))
                .toList();
    }

    @GetMapping("/{creditoId}")
    @Operation(summary = "Estado de un crédito")
    public CreditoDto obtener(@PathVariable UUID creditoId) {
        return CreditoDto.de(creditos.estadoDe(UsuarioActual.id(), creditoId));
    }

    @GetMapping("/{creditoId}/cuotas")
    @Operation(summary = "El cuadro de amortización completo")
    public List<CuotaDto> cuotas(@PathVariable UUID creditoId) {
        return creditos.cuotasDe(UsuarioActual.id(), creditoId).stream()
                .map(CuotaDto::de)
                .toList();
    }

    @PostMapping
    @Operation(summary = "Registra un crédito con su cuadro de amortización")
    public ResponseEntity<CreditoDto> crear(@Valid @RequestBody CrearCreditoRequest peticion) {
        UUID usuarioId = UsuarioActual.id();

        // La plantilla lleva los datos de cabecera; el servicio construye el crédito real para
        // no exponer el constructor de la entidad al controlador.
        Credito plantilla = new Credito(null, peticion.entidad(), peticion.montoOriginal(),
                peticion.plazoCuotas());
        plantilla.setNumeroOperacion(peticion.numeroOperacion());
        plantilla.setDescripcion(peticion.descripcion());
        plantilla.setTasaEa(peticion.tasaEa());
        plantilla.setDiaPago(peticion.diaPago() == null ? null
                : peticion.diaPago().shortValue());
        plantilla.setFechaDesembolso(peticion.fechaDesembolso());
        plantilla.setFechaVencimiento(peticion.fechaVencimiento());

        var credito = creditos.crear(usuarioId, plantilla, construirPlan(peticion.cuotas()));
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(CreditoDto.de(creditos.estadoDe(usuarioId, credito.getId())));
    }

    @PutMapping("/cuotas/{cuotaId}")
    @Operation(summary = "Marca una cuota como pagada, o la devuelve a pendiente")
    public CuotaDto marcarCuota(@PathVariable UUID cuotaId,
                                @Valid @RequestBody MarcarCuotaRequest peticion) {
        return CuotaDto.de(creditos.marcarCuota(UsuarioActual.id(), cuotaId, peticion.pagada(),
                peticion.fecha(), peticion.monto()));
    }

    /**
     * Qué pasaría si se abonara de más a capital.
     *
     * @param modo {@code REDUCIR_CUOTA} para bajar el importe mensual, o {@code REDUCIR_PLAZO}
     *             para terminar antes pagando lo mismo
     */
    @GetMapping("/{creditoId}/simulacion")
    @Operation(summary = "Simula un abono extraordinario a capital")
    public SimulacionDto simular(@PathVariable UUID creditoId,
                                 @RequestParam BigDecimal abono,
                                 @RequestParam(defaultValue = "REDUCIR_PLAZO")
                                 ServicioCreditos.ModoDeAbono modo) {
        return SimulacionDto.de(creditos.simular(UsuarioActual.id(), creditoId, abono, modo));
    }

    @DeleteMapping("/{creditoId}")
    @Operation(summary = "Elimina el crédito y su cuadro")
    public ResponseEntity<Void> eliminar(@PathVariable UUID creditoId) {
        creditos.eliminar(UsuarioActual.id(), creditoId);
        return ResponseEntity.noContent().build();
    }

    private static List<CuotaCredito> construirPlan(List<CuotaDelPlan> filas) {
        List<CuotaCredito> plan = new ArrayList<>();

        for (CuotaDelPlan fila : filas) {
            CuotaCredito cuota = new CuotaCredito(fila.numero(), fila.fecha(),
                    fila.saldoCapital(), fila.capital(), fila.interes(), fila.valorCuota());

            cuota.setDias(fila.dias() == null ? null : fila.dias().shortValue());
            cuota.setMora(oCero(fila.mora()));
            cuota.setMipyme(oCero(fila.mipyme()));
            cuota.setSeguro(oCero(fila.seguro()));
            cuota.setOtros(oCero(fila.otros()));

            if (Boolean.TRUE.equals(fila.pagada())) {
                cuota.marcarPagada(fila.fechaPago(), fila.valorCuota());
            }
            plan.add(cuota);
        }
        return plan;
    }

    private static BigDecimal oCero(BigDecimal valor) {
        return valor == null ? BigDecimal.ZERO : valor;
    }
}
