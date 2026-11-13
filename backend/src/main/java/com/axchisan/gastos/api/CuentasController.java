package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosCuenta.ActualizarCuentaRequest;
import com.axchisan.gastos.api.dto.DtosCuenta.CrearCuentaRequest;
import com.axchisan.gastos.api.dto.DtosCuenta.CuentaDto;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioCuentas;
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
@RequestMapping("/api/cuentas")
@Tag(name = "Cuentas", description = "Saldo real de cada banco, billetera y del efectivo")
public class CuentasController {

    private final ServicioCuentas cuentas;

    public CuentasController(ServicioCuentas cuentas) {
        this.cuentas = cuentas;
    }

    @GetMapping
    @Operation(summary = "Lista las cuentas con su último saldo")
    public List<CuentaDto> listar() {
        return cuentas.listar(UsuarioActual.id()).stream().map(CuentaDto::de).toList();
    }

    @PostMapping
    @Operation(summary = "Registra una cuenta")
    public ResponseEntity<CuentaDto> crear(@Valid @RequestBody CrearCuentaRequest peticion) {
        var cuenta = cuentas.crear(UsuarioActual.id(), peticion.nombre(), peticion.tipo(),
                peticion.saldo(), peticion.saldoAl());
        return ResponseEntity.status(HttpStatus.CREATED).body(CuentaDto.de(cuenta));
    }

    @PatchMapping("/{cuentaId}")
    @Operation(summary = "Modifica una cuenta o anota su saldo de hoy")
    public CuentaDto actualizar(@PathVariable UUID cuentaId,
                                @Valid @RequestBody ActualizarCuentaRequest peticion) {
        return CuentaDto.de(cuentas.actualizar(UsuarioActual.id(), cuentaId, peticion.nombre(),
                peticion.tipo(), peticion.saldo(), peticion.saldoAl(), peticion.activa()));
    }

    @DeleteMapping("/{cuentaId}")
    @Operation(summary = "Elimina una cuenta")
    public ResponseEntity<Void> eliminar(@PathVariable UUID cuentaId) {
        cuentas.eliminar(UsuarioActual.id(), cuentaId);
        return ResponseEntity.noContent().build();
    }
}
