package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosCredenciales.CambiarEmailRequest;
import com.axchisan.gastos.api.dto.DtosCredenciales.CambiarNombreRequest;
import com.axchisan.gastos.api.dto.DtosCredenciales.CambiarPasswordRequest;
import com.axchisan.gastos.api.dto.DtosCredenciales.EstadoRegistro;
import com.axchisan.gastos.api.dto.RespuestaSesion;
import com.axchisan.gastos.api.dto.SolicitudLogin;
import com.axchisan.gastos.api.dto.SolicitudRefresco;
import com.axchisan.gastos.api.dto.SolicitudRegistro;
import com.axchisan.gastos.api.dto.UsuarioDto;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.axchisan.gastos.seguridad.ServicioAutenticacion;
import com.axchisan.gastos.seguridad.UsuarioActual;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Autenticación", description = "Registro, inicio de sesión y gestión de tokens")
public class AutenticacionController {

    private final ServicioAutenticacion autenticacion;
    private final UsuarioRepository usuarios;

    public AutenticacionController(ServicioAutenticacion autenticacion,
                                   UsuarioRepository usuarios) {
        this.autenticacion = autenticacion;
        this.usuarios = usuarios;
    }

    @PostMapping("/registro")
    @Operation(summary = "Crea una cuenta y devuelve la sesión ya iniciada")
    public ResponseEntity<RespuestaSesion> registrar(@Valid @RequestBody SolicitudRegistro peticion) {
        var sesion = autenticacion.registrar(
                peticion.email(), peticion.password(), peticion.nombre());
        return ResponseEntity.status(HttpStatus.CREATED).body(RespuestaSesion.de(sesion));
    }

    @PostMapping("/login")
    @Operation(summary = "Inicia sesión con correo y contraseña")
    public RespuestaSesion iniciarSesion(@Valid @RequestBody SolicitudLogin peticion) {
        return RespuestaSesion.de(
                autenticacion.iniciarSesion(peticion.email(), peticion.password()));
    }

    @PostMapping("/refresh")
    @Operation(summary = "Renueva la sesión rotando el token de refresco")
    public RespuestaSesion refrescar(@Valid @RequestBody SolicitudRefresco peticion) {
        return RespuestaSesion.de(autenticacion.refrescar(peticion.refreshToken()));
    }

    @PostMapping("/logout")
    @Operation(summary = "Cierra la sesión asociada al token de refresco")
    public ResponseEntity<Void> cerrarSesion(@Valid @RequestBody SolicitudRefresco peticion) {
        autenticacion.cerrarSesion(peticion.refreshToken());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/yo")
    @Operation(summary = "Devuelve los datos del usuario autenticado")
    public UsuarioDto yo() {
        return usuarios.findById(UsuarioActual.id())
                .map(UsuarioDto::de)
                .orElseThrow(() -> new IllegalStateException(
                        "El token corresponde a un usuario que ya no existe"));
    }

    @GetMapping("/registro-abierto")
    @Operation(summary = "Indica si se admiten cuentas nuevas. La aplicación lo consulta para "
            + "decidir si muestra la opción de registrarse")
    public EstadoRegistro registroAbierto() {
        return new EstadoRegistro(autenticacion.admiteRegistro());
    }

    @PatchMapping("/password")
    @Operation(summary = "Cambia la contraseña y cierra el resto de sesiones")
    public RespuestaSesion cambiarPassword(
            @Valid @RequestBody CambiarPasswordRequest peticion) {
        return RespuestaSesion.de(autenticacion.cambiarPassword(
                UsuarioActual.id(), peticion.passwordActual(), peticion.passwordNueva()));
    }

    @PatchMapping("/email")
    @Operation(summary = "Cambia el correo de acceso y cierra el resto de sesiones")
    public RespuestaSesion cambiarEmail(@Valid @RequestBody CambiarEmailRequest peticion) {
        return RespuestaSesion.de(autenticacion.cambiarEmail(
                UsuarioActual.id(), peticion.password(), peticion.emailNuevo()));
    }

    @PatchMapping("/nombre")
    @Operation(summary = "Cambia el nombre visible")
    public UsuarioDto cambiarNombre(@Valid @RequestBody CambiarNombreRequest peticion) {
        return UsuarioDto.de(
                autenticacion.cambiarNombre(UsuarioActual.id(), peticion.nombre()));
    }
}
