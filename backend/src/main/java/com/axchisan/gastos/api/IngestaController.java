package com.axchisan.gastos.api;

import com.axchisan.gastos.dominio.ClaveIngesta;
import com.axchisan.gastos.dominio.MovimientoDetectado;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioIngesta;
import com.axchisan.gastos.servicio.ServicioIngesta.Aviso;
import com.axchisan.gastos.servicio.ServicioIngesta.ResultadoLote;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Avisos del banco que llegan solos: el teléfono al recibir un SMS y el script de Gmail al
 * llegar un correo de alertas. Se autentican con una clave de ingesta (cabecera
 * {@value #CABECERA}), no con la sesión, que caduca.
 */
@RestController
@Tag(name = "Ingesta", description = "Avisos que envían el teléfono y Gmail sin la sesión")
public class IngestaController {

    public static final String CABECERA = "X-Clave-Ingesta";

    private final ServicioIngesta ingesta;

    public IngestaController(ServicioIngesta ingesta) {
        this.ingesta = ingesta;
    }

    public record AvisoDto(@NotNull MovimientoDetectado.Origen origen,
                           @NotNull @Size(max = 4000) String texto) {
    }

    public record LoteRequest(@NotEmpty @Size(max = ServicioIngesta.MAXIMO_POR_LOTE)
                              List<@Valid AvisoDto> avisos) {

        List<Aviso> comoAvisos() {
            return avisos.stream().map(a -> new Aviso(a.origen(), a.texto())).toList();
        }
    }

    public record ClaveDto(UUID id, String nombre, OffsetDateTime creada, OffsetDateTime usada) {

        static ClaveDto de(ClaveIngesta c) {
            return new ClaveDto(c.getId(), c.getNombre(), c.getCreatedAt(), c.getUsadaEn());
        }
    }

    /** @param clave solo aparece en esta respuesta: no se puede volver a consultar */
    public record ClaveNuevaDto(UUID id, String nombre, String clave) {
    }

    public record CrearClaveRequest(@Size(max = 40) String nombre) {
    }

    @PostMapping("/api/ingesta/avisos")
    @Operation(summary = "Recibe avisos con la clave de ingesta (teléfono, Gmail)")
    public ResponseEntity<?> recibirConClave(
            @RequestHeader(value = CABECERA, required = false) String clave,
            @Valid @RequestBody LoteRequest peticion) {
        var usuario = ingesta.autenticar(clave);
        if (usuario.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "error", "clave_invalida",
                    "mensaje", "La clave de ingesta no existe o fue revocada"));
        }
        return ResponseEntity.ok(ingesta.recibir(usuario.get(), peticion.comoAvisos()));
    }

    @PostMapping("/api/detectados/avisos/lote")
    @Operation(summary = "Recibe varios avisos con la sesión (historial de SMS desde la app)")
    public ResultadoLote recibirConSesion(@Valid @RequestBody LoteRequest peticion) {
        return ingesta.recibir(UsuarioActual.id(), peticion.comoAvisos());
    }

    @GetMapping("/api/ingesta/claves")
    @Operation(summary = "Las claves de ingesta activas")
    public List<ClaveDto> claves() {
        return ingesta.listar(UsuarioActual.id()).stream().map(ClaveDto::de).toList();
    }

    @PostMapping("/api/ingesta/claves")
    @Operation(summary = "Crea una clave de ingesta; se muestra una sola vez")
    public ResponseEntity<ClaveNuevaDto> crearClave(@Valid @RequestBody CrearClaveRequest p) {
        var nueva = ingesta.crear(UsuarioActual.id(), p.nombre());
        return ResponseEntity.status(HttpStatus.CREATED).body(new ClaveNuevaDto(
                nueva.clave().getId(), nueva.clave().getNombre(), nueva.secreto()));
    }

    @DeleteMapping("/api/ingesta/claves/{id}")
    @Operation(summary = "Revoca una clave de ingesta")
    public ResponseEntity<Void> revocar(@PathVariable UUID id) {
        ingesta.revocar(UsuarioActual.id(), id);
        return ResponseEntity.noContent().build();
    }
}
