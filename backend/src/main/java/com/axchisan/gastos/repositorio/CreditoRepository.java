package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.Credito;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CreditoRepository extends JpaRepository<Credito, UUID> {

    @Query("""
            SELECT c FROM Credito c
             WHERE c.usuario.id = :usuarioId
             ORDER BY c.activo DESC, c.createdAt
            """)
    List<Credito> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT c FROM Credito c WHERE c.usuario.id = :usuarioId AND c.id = :id")
    Optional<Credito> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    /**
     * Lo que queda por pagar de todos los créditos activos.
     *
     * <p>Entra en el patrimonio neto igual que una deuda: es dinero comprometido, aunque su
     * calendario esté cerrado.
     */
    @Query("""
            SELECT coalesce(sum(q.valorCuota), 0) FROM CuotaCredito q
             WHERE q.credito.usuario.id = :usuarioId
               AND q.credito.activo = true
               AND q.pagada = false
            """)
    BigDecimal pendienteTotal(@Param("usuarioId") UUID usuarioId);

    /**
     * Lo que vence en un mes y sigue sin pagarse.
     *
     * <p>Es lo que convierte el crédito en un compromiso del presupuesto en lugar de un dato
     * suelto en otra pantalla.
     */
    @Query("""
            SELECT coalesce(sum(q.valorCuota), 0) FROM CuotaCredito q
             WHERE q.credito.usuario.id = :usuarioId
               AND q.credito.activo = true
               AND q.pagada = false
               AND q.fecha BETWEEN :inicio AND :fin
            """)
    BigDecimal cuotasPendientesEntre(@Param("usuarioId") UUID usuarioId,
                                     @Param("inicio") java.time.LocalDate inicio,
                                     @Param("fin") java.time.LocalDate fin);

    /** Lo que vencía en el mes y ya se pagó. */
    @Query("""
            SELECT coalesce(sum(coalesce(q.montoPagado, q.valorCuota)), 0) FROM CuotaCredito q
             WHERE q.credito.usuario.id = :usuarioId
               AND q.credito.activo = true
               AND q.pagada = true
               AND q.fecha BETWEEN :inicio AND :fin
            """)
    BigDecimal cuotasPagadasEntre(@Param("usuarioId") UUID usuarioId,
                                  @Param("inicio") java.time.LocalDate inicio,
                                  @Param("fin") java.time.LocalDate fin);
}
