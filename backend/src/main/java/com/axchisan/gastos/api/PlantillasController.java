package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosPlantilla.ActualizarPlantillaRequest;
import com.axchisan.gastos.api.dto.DtosPlantilla.CrearPlantillaRequest;
import com.axchisan.gastos.api.dto.DtosPlantilla.PlantillaDto;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioPlantillas;
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
@RequestMapping("/api/plantillas")
@Tag(name = "Plantillas", description = "Gastos fijos que se copian a cada mes nuevo")
public class PlantillasController {

    private final ServicioPlantillas plantillas;

    public PlantillasController(ServicioPlantillas plantillas) {
        this.plantillas = plantillas;
    }

    @GetMapping
    @Operation(summary = "Lista las plantillas de gastos fijos")
    public List<PlantillaDto> listar() {
        return plantillas.listar(UsuarioActual.id()).stream().map(PlantillaDto::de).toList();
    }

    @PostMapping
    @Operation(summary = "Crea una plantilla de gasto fijo")
    public ResponseEntity<PlantillaDto> crear(@Valid @RequestBody CrearPlantillaRequest peticion) {
        var plantilla = plantillas.crear(UsuarioActual.id(), peticion.nombre(),
                peticion.categoria(), peticion.montoDefault(), peticion.diaVencimiento(),
                peticion.orden());
        return ResponseEntity.status(HttpStatus.CREATED).body(PlantillaDto.de(plantilla));
    }

    @PatchMapping("/{plantillaId}")
    @Operation(summary = "Modifica una plantilla. No altera los meses ya creados")
    public PlantillaDto actualizar(@PathVariable UUID plantillaId,
                                   @Valid @RequestBody ActualizarPlantillaRequest peticion) {
        return PlantillaDto.de(plantillas.actualizar(UsuarioActual.id(), plantillaId,
                peticion.nombre(), peticion.categoria(), peticion.montoDefault(),
                peticion.diaVencimiento(), peticion.activo(), peticion.orden()));
    }

    @PostMapping("/{plantillaId}/desactivar")
    @Operation(summary = "Deja de copiar la plantilla a los meses nuevos, sin borrar el histórico")
    public ResponseEntity<Void> desactivar(@PathVariable UUID plantillaId) {
        plantillas.desactivar(UsuarioActual.id(), plantillaId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{plantillaId}")
    @Operation(summary = "Elimina la plantilla; los gastos ya creados se conservan")
    public ResponseEntity<Void> eliminar(@PathVariable UUID plantillaId) {
        plantillas.eliminar(UsuarioActual.id(), plantillaId);
        return ResponseEntity.noContent().build();
    }
}
