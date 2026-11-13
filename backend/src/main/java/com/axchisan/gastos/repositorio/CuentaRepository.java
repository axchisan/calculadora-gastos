package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.Cuenta;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CuentaRepository extends JpaRepository<Cuenta, UUID> {

    @Query("""
            SELECT c FROM Cuenta c
             WHERE c.usuario.id = :usuarioId
             ORDER BY c.activa DESC, c.orden, c.nombre
            """)
    List<Cuenta> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT c FROM Cuenta c WHERE c.usuario.id = :usuarioId AND c.id = :id")
    Optional<Cuenta> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);
}
