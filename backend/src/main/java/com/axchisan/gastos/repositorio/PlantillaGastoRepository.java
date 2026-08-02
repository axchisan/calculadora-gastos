package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.PlantillaGasto;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PlantillaGastoRepository extends JpaRepository<PlantillaGasto, UUID> {

    @Query("""
            SELECT p FROM PlantillaGasto p
             WHERE p.usuario.id = :usuarioId
             ORDER BY p.orden ASC, p.nombre ASC
            """)
    List<PlantillaGasto> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    /** Plantillas que se copian al crear un mes nuevo. */
    @Query("""
            SELECT p FROM PlantillaGasto p
             WHERE p.usuario.id = :usuarioId AND p.activo = true
             ORDER BY p.orden ASC, p.nombre ASC
            """)
    List<PlantillaGasto> listarActivas(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT p FROM PlantillaGasto p WHERE p.usuario.id = :usuarioId AND p.id = :id")
    Optional<PlantillaGasto> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                              @Param("id") UUID id);
}
