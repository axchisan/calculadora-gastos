package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.Tarjeta;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TarjetaRepository extends JpaRepository<Tarjeta, UUID> {

    @Query("""
            SELECT t FROM Tarjeta t
             WHERE t.usuario.id = :usuarioId
             ORDER BY t.activa DESC, t.orden, t.nombre
            """)
    List<Tarjeta> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT t FROM Tarjeta t WHERE t.usuario.id = :usuarioId AND t.id = :id")
    Optional<Tarjeta> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    @Query("""
            SELECT t FROM Tarjeta t
             WHERE t.usuario.id = :usuarioId AND t.activa = true AND t.tipo = 'CREDITO'
             ORDER BY t.orden, t.nombre
            """)
    List<Tarjeta> listarDeCredito(@Param("usuarioId") UUID usuarioId);
}
