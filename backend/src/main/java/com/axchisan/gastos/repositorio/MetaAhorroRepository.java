package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.MetaAhorro;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MetaAhorroRepository extends JpaRepository<MetaAhorro, UUID> {

    @Query("""
            SELECT m FROM MetaAhorro m
             WHERE m.usuario.id = :usuarioId
             ORDER BY m.activa DESC, m.prioridad ASC
            """)
    List<MetaAhorro> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    /**
     * Metas activas en orden de prioridad.
     *
     * <p>El orden importa: las que reparten un porcentaje del sobrante se calculan sobre lo que
     * queda tras las anteriores.
     */
    @Query("""
            SELECT m FROM MetaAhorro m
             WHERE m.usuario.id = :usuarioId AND m.activa = true
             ORDER BY m.prioridad ASC, m.nombre ASC
            """)
    List<MetaAhorro> listarActivas(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT m FROM MetaAhorro m WHERE m.usuario.id = :usuarioId AND m.id = :id")
    Optional<MetaAhorro> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    /** Total ahorrado, base del cálculo del patrimonio neto. */
    @Query("""
            SELECT coalesce(sum(m.saldoAcumulado), 0) FROM MetaAhorro m
             WHERE m.usuario.id = :usuarioId
            """)
    BigDecimal saldoTotal(@Param("usuarioId") UUID usuarioId);
}
