package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosDetectados.AceptarRequest;
import com.axchisan.gastos.api.dto.DtosDetectados.AvisoRequest;
import com.axchisan.gastos.api.dto.DtosDetectados.AvisoResponse;
import com.axchisan.gastos.api.dto.DtosDetectados.CrearReglaRequest;
import com.axchisan.gastos.api.dto.DtosDetectados.DescartarRequest;
import com.axchisan.gastos.api.dto.DtosDetectados.DetectadoDto;
import com.axchisan.gastos.api.dto.DtosDetectados.ExtractoRequest;
import com.axchisan.gastos.api.dto.DtosDetectados.ReglaDto;
import com.axchisan.gastos.dominio.MovimientoDetectado;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioDetectados;
import com.axchisan.gastos.servicio.ServicioDetectados.ResumenImportacion;
import com.axchisan.gastos.servicio.ServicioSueldo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Base64;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/detectados")
@Tag(name = "Detectados", description = "Movimientos que llegan solos (correo, SMS, extractos) "
        + "y esperan revisión")
public class DetectadosController {

    private final ServicioDetectados servicio;

    public DetectadosController(ServicioDetectados servicio) {
        this.servicio = servicio;
    }

    @GetMapping
    @Operation(summary = "La bandeja; por defecto, lo pendiente")
    public List<DetectadoDto> listar(
            @RequestParam(required = false) List<MovimientoDetectado.Estado> estado) {
        return servicio.listar(UsuarioActual.id(), estado).stream()
                .map(DetectadoDto::de).toList();
    }

    @PostMapping("/avisos")
    @Operation(summary = "Recibe un aviso del banco (correo o SMS) tal como llegó")
    public ResponseEntity<AvisoResponse> aviso(@Valid @RequestBody AvisoRequest peticion) {
        var r = servicio.recibirAviso(UsuarioActual.id(), peticion.origen(), peticion.texto());
        var cuerpo = new AvisoResponse(r.resultado().name(),
                r.detectado() == null ? null : DetectadoDto.de(r.detectado()));
        return ResponseEntity.status(r.resultado() == ServicioDetectados.Resultado.NUEVO
                ? HttpStatus.CREATED : HttpStatus.OK).body(cuerpo);
    }

    @PostMapping("/extractos")
    @Operation(summary = "Importa el PDF «Movimientos» de Bancolombia (en base64)")
    public ResumenImportacion extracto(@Valid @RequestBody ExtractoRequest peticion) {
        byte[] pdf;
        try {
            pdf = Base64.getMimeDecoder().decode(peticion.pdf());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("El PDF no llegó bien codificado en base64");
        }
        return servicio.importarExtracto(UsuarioActual.id(), pdf,
                peticion.hoy() == null ? ServicioSueldo.hoy() : peticion.hoy());
    }

    @PostMapping("/{id}/aceptar")
    @Operation(summary = "Lo registra como compra, gasto pagado, ingreso o abono")
    public DetectadoDto aceptar(@PathVariable UUID id, @Valid @RequestBody AceptarRequest p) {
        return DetectadoDto.de(servicio.aceptar(UsuarioActual.id(), id,
                new ServicioDetectados.Aceptacion(p.destino(), p.descripcion(), p.categoria(),
                        p.tipoIngreso(), p.medio(), p.deudaId(), p.mesId(),
                        Boolean.TRUE.equals(p.siempre()))));
    }

    @PostMapping("/{id}/descartar")
    @Operation(summary = "Lo saca de la bandeja sin registrarlo")
    public DetectadoDto descartar(@PathVariable UUID id,
                                  @Valid @RequestBody(required = false) DescartarRequest peticion) {
        return DetectadoDto.de(servicio.descartar(UsuarioActual.id(), id,
                peticion == null ? null : peticion.motivo(),
                peticion != null && Boolean.TRUE.equals(peticion.siempre())));
    }

    @PostMapping("/{id}/ya-registrado")
    @Operation(summary = "Lo marca como algo que ya estaba apuntado")
    public DetectadoDto yaRegistrado(@PathVariable UUID id) {
        return DetectadoDto.de(servicio.marcarYaRegistrado(UsuarioActual.id(), id));
    }

    @PostMapping("/{id}/reabrir")
    @Operation(summary = "Lo devuelve a la bandeja")
    public DetectadoDto reabrir(@PathVariable UUID id) {
        return DetectadoDto.de(servicio.reabrir(UsuarioActual.id(), id));
    }

    @GetMapping("/reglas")
    @Operation(summary = "Las reglas para contrapartes conocidas")
    public List<ReglaDto> reglas() {
        return servicio.reglas(UsuarioActual.id()).stream().map(ReglaDto::de).toList();
    }

    @PostMapping("/reglas")
    @Operation(summary = "Crea una regla y la aplica a lo pendiente")
    public ResponseEntity<ReglaDto> crearRegla(@Valid @RequestBody CrearReglaRequest p) {
        var regla = servicio.crearRegla(UsuarioActual.id(), p.campo(), p.valor(), p.accion(),
                p.destino(), p.categoria(), p.nombre(), p.objetivoId());
        return ResponseEntity.status(HttpStatus.CREATED).body(ReglaDto.de(regla));
    }

    @DeleteMapping("/reglas/{id}")
    @Operation(summary = "Elimina una regla")
    public ResponseEntity<Void> eliminarRegla(@PathVariable UUID id) {
        servicio.eliminarRegla(UsuarioActual.id(), id);
        return ResponseEntity.noContent().build();
    }
}
