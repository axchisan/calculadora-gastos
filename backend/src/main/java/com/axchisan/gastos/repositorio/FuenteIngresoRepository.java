package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.FuenteIngreso;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FuenteIngresoRepository extends JpaRepository<FuenteIngreso, UUID> {

    @Query("""
            SELECT f FROM FuenteIngreso f
             WHERE f.usuario.id = :usuarioId
             ORDER BY f.activo DESC, f.fechaInicio DESC
            """)
    List<FuenteIngreso> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT f FROM FuenteIngreso f WHERE f.usuario.id = :usuarioId AND f.id = :id")
    Optional<FuenteIngreso> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                             @Param("id") UUID id);
}
