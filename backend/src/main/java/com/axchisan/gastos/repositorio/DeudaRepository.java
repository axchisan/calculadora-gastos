package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.Deuda;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeudaRepository extends JpaRepository<Deuda, UUID> {

    @Query("""
            SELECT d FROM Deuda d
             WHERE d.usuario.id = :usuarioId
             ORDER BY d.activa DESC, d.saldo DESC
            """)
    List<Deuda> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    @Query("""
            SELECT d FROM Deuda d
             WHERE d.usuario.id = :usuarioId AND d.activa = true
             ORDER BY d.saldo DESC
            """)
    List<Deuda> listarActivas(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT d FROM Deuda d WHERE d.usuario.id = :usuarioId AND d.id = :id")
    Optional<Deuda> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    /** Total adeudado, base del cálculo del patrimonio neto. */
    @Query("""
            SELECT coalesce(sum(d.saldo), 0) FROM Deuda d
             WHERE d.usuario.id = :usuarioId AND d.activa = true
            """)
    BigDecimal saldoTotal(@Param("usuarioId") UUID usuarioId);
}
