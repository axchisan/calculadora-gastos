package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.ReglaDeteccion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ReglaDeteccionRepository extends JpaRepository<ReglaDeteccion, UUID> {

    @Query("""
            SELECT r FROM ReglaDeteccion r
             WHERE r.usuario.id = :usuarioId
             ORDER BY r.createdAt
            """)
    List<ReglaDeteccion> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT r FROM ReglaDeteccion r WHERE r.usuario.id = :usuarioId AND r.id = :id")
    Optional<ReglaDeteccion> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                              @Param("id") UUID id);
}
