package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.CuotaCredito;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CuotaCreditoRepository extends JpaRepository<CuotaCredito, UUID> {

    @Query("""
            SELECT q FROM CuotaCredito q
             WHERE q.credito.id = :creditoId
             ORDER BY q.numero
            """)
    List<CuotaCredito> listarDelCredito(@Param("creditoId") UUID creditoId);

    @Query("""
            SELECT q FROM CuotaCredito q
             WHERE q.credito.usuario.id = :usuarioId AND q.id = :id
            """)
    Optional<CuotaCredito> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                            @Param("id") UUID id);

    /**
     * Cuotas sin pagar de los créditos activos que vencen hasta una fecha, vencidas incluidas.
     * Trae el crédito en la misma consulta porque quien las pide siempre muestra su entidad.
     */
    @Query("""
            SELECT q FROM CuotaCredito q JOIN FETCH q.credito c
             WHERE c.usuario.id = :usuarioId
               AND c.activo = true
               AND q.pagada = false
               AND q.fecha <= :hasta
             ORDER BY q.fecha, q.numero
            """)
    List<CuotaCredito> pendientesHasta(@Param("usuarioId") UUID usuarioId,
                                       @Param("hasta") java.time.LocalDate hasta);

    /** Cuotas pagadas de créditos activos que vencían entre dos fechas, con su crédito. */
    @Query("""
            SELECT q FROM CuotaCredito q JOIN FETCH q.credito c
             WHERE c.usuario.id = :usuarioId
               AND c.activo = true
               AND q.pagada = true
               AND q.fecha BETWEEN :inicio AND :fin
             ORDER BY q.fecha
            """)
    List<CuotaCredito> pagadasEntre(@Param("usuarioId") UUID usuarioId,
                                    @Param("inicio") java.time.LocalDate inicio,
                                    @Param("fin") java.time.LocalDate fin);
}
