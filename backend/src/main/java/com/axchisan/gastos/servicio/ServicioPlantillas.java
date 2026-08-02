package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.PlantillaGasto;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.PlantillaGastoRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/** Plantillas de gastos fijos que se copian a cada mes nuevo. */
@Service
public class ServicioPlantillas {

    private final PlantillaGastoRepository plantillas;
    private final UsuarioRepository usuarios;

    public ServicioPlantillas(PlantillaGastoRepository plantillas, UsuarioRepository usuarios) {
        this.plantillas = plantillas;
        this.usuarios = usuarios;
    }

    @Transactional(readOnly = true)
    public List<PlantillaGasto> listar(UUID usuarioId) {
        return plantillas.listarDelUsuario(usuarioId);
    }

    @Transactional
    public PlantillaGasto crear(UUID usuarioId, String nombre, CategoriaGasto categoria,
                                BigDecimal montoDefault, Short diaVencimiento, Short orden) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));

        PlantillaGasto plantilla = new PlantillaGasto(usuario, nombre, categoria, montoDefault);
        plantilla.setDiaVencimiento(diaVencimiento);
        if (orden != null) {
            plantilla.setOrden(orden);
        }
        return plantillas.save(plantilla);
    }

    @Transactional
    public PlantillaGasto actualizar(UUID usuarioId, UUID plantillaId, String nombre,
                                     CategoriaGasto categoria, BigDecimal montoDefault,
                                     Short diaVencimiento, Boolean activo, Short orden) {
        PlantillaGasto plantilla = buscar(usuarioId, plantillaId);

        if (nombre != null) {
            plantilla.setNombre(nombre);
        }
        if (categoria != null) {
            plantilla.setCategoria(categoria);
        }
        if (montoDefault != null) {
            plantilla.setMontoDefault(montoDefault);
        }
        if (diaVencimiento != null) {
            plantilla.setDiaVencimiento(diaVencimiento);
        }
        if (activo != null) {
            plantilla.setActivo(activo);
        }
        if (orden != null) {
            plantilla.setOrden(orden);
        }
        return plantillas.save(plantilla);
    }

    /**
     * Desactiva la plantilla en lugar de borrarla.
     *
     * <p>Los gastos ya creados a partir de ella conservan la referencia, y el histórico sigue
     * mostrando de dónde vino cada uno.
     */
    @Transactional
    public void desactivar(UUID usuarioId, UUID plantillaId) {
        PlantillaGasto plantilla = buscar(usuarioId, plantillaId);
        plantilla.setActivo(false);
        plantillas.save(plantilla);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID plantillaId) {
        plantillas.delete(buscar(usuarioId, plantillaId));
    }

    @Transactional(readOnly = true)
    public PlantillaGasto buscar(UUID usuarioId, UUID plantillaId) {
        return plantillas.buscarDelUsuario(usuarioId, plantillaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la plantilla", plantillaId));
    }
}
