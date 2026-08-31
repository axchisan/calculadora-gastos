package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosTransporte.ActualizarConfigRequest;
import com.axchisan.gastos.api.dto.DtosTransporte.CambiarTipoDiaRequest;
import com.axchisan.gastos.api.dto.DtosTransporte.ConfigDto;
import com.axchisan.gastos.api.dto.DtosTransporte.ConfirmarDiaRequest;
import com.axchisan.gastos.api.dto.DtosTransporte.EscenariosDto;
import com.axchisan.gastos.api.dto.DtosTransporte.FijarPasajesRequest;
import com.axchisan.gastos.api.dto.DtosTransporte.ResumenDto;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioTransporteMes;
import com.axchisan.gastos.transporte.ResumenTransporte;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * Cálculo del gasto en transporte del mes.
 *
 * <p>Todas las operaciones que modifican algo devuelven el resumen recalculado, para que el
 * cliente pueda actualizar la pantalla con una sola petición.
 */
@RestController
@RequestMapping("/api/meses/{mesId}/transporte")
@Tag(name = "Transporte", description = "Calendario y cálculo del gasto en pasajes")
public class TransporteController {

    private final ServicioTransporteMes transporte;

    public TransporteController(ServicioTransporteMes transporte) {
        this.transporte = transporte;
    }

    @GetMapping
    @Operation(summary = "Resumen del transporte del mes con el detalle día a día")
    public ResumenDto resumen(@PathVariable UUID mesId) {
        UUID usuarioId = UsuarioActual.id();
        ResumenTransporte resumen = transporte.resumen(usuarioId, mesId);
        return ResumenDto.de(resumen, transporte.dias(usuarioId, mesId));
    }

    @GetMapping("/configuracion")
    @Operation(summary = "Parámetros del cálculo: tarifa, días laborales y de karate")
    public ConfigDto configuracion(@PathVariable UUID mesId) {
        return ConfigDto.de(transporte.configuracion(UsuarioActual.id(), mesId));
    }

    @GetMapping("/escenarios")
    @Operation(summary = "Proyecciones según cuántos días se trabaje desde casa")
    public EscenariosDto escenarios(@PathVariable UUID mesId) {
        return EscenariosDto.de(transporte.escenarios(UsuarioActual.id(), mesId));
    }

    @PatchMapping("/configuracion")
    @Operation(summary = "Cambia los parámetros del cálculo y recalcula")
    public ResumenDto actualizarConfiguracion(@PathVariable UUID mesId,
                                              @Valid @RequestBody ActualizarConfigRequest peticion) {
        UUID usuarioId = UsuarioActual.id();
        ResumenTransporte resumen = transporte.actualizarConfiguracion(
                usuarioId, mesId, peticion.valorPasaje(), peticion.comisionRecarga(), peticion.pasajesDiaOficina(),
                peticion.pasajesExtraKarate(), peticion.pasajesKarateDesdeCasa(),
                peticion.diasLaborales(), peticion.diasKarate(), peticion.diasRemotosPorSemana(),
                peticion.debeRegenerar());
        return ResumenDto.de(resumen, transporte.dias(usuarioId, mesId));
    }

    @PostMapping("/regenerar")
    @Operation(summary = "Descarta los ajustes del calendario y vuelve a proponerlo desde cero")
    public ResumenDto regenerar(@PathVariable UUID mesId) {
        UUID usuarioId = UsuarioActual.id();
        ResumenTransporte resumen = transporte.regenerar(usuarioId, mesId);
        return ResumenDto.de(resumen, transporte.dias(usuarioId, mesId));
    }

    @PatchMapping("/dias/{diaId}/tipo")
    @Operation(summary = "Reclasifica un día: oficina, remoto, vacaciones o ausencia")
    public ResumenDto cambiarTipo(@PathVariable UUID mesId, @PathVariable UUID diaId,
                                  @Valid @RequestBody CambiarTipoDiaRequest peticion) {
        UUID usuarioId = UsuarioActual.id();
        ResumenTransporte resumen = transporte.cambiarTipoDia(usuarioId, mesId, diaId,
                peticion.tipo());
        return ResumenDto.de(resumen, transporte.dias(usuarioId, mesId));
    }

    @PatchMapping("/dias/{diaId}/pasajes")
    @Operation(summary = "Fija a mano los pasajes de un día concreto")
    public ResumenDto fijarPasajes(@PathVariable UUID mesId, @PathVariable UUID diaId,
                                   @Valid @RequestBody FijarPasajesRequest peticion) {
        UUID usuarioId = UsuarioActual.id();
        ResumenTransporte resumen = transporte.fijarPasajes(usuarioId, mesId, diaId,
                peticion.pasajes());
        return ResumenDto.de(resumen, transporte.dias(usuarioId, mesId));
    }

    @PatchMapping("/dias/{diaId}/confirmar")
    @Operation(summary = "Confirma que el día ya transcurrió, para comparar con lo presupuestado")
    public ResumenDto confirmar(@PathVariable UUID mesId, @PathVariable UUID diaId,
                                @Valid @RequestBody ConfirmarDiaRequest peticion) {
        UUID usuarioId = UsuarioActual.id();
        ResumenTransporte resumen = transporte.confirmarDia(usuarioId, mesId, diaId,
                peticion.confirmado());
        return ResumenDto.de(resumen, transporte.dias(usuarioId, mesId));
    }
}
