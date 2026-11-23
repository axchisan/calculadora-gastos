package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.MovimientoDetectado;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MovimientoDetectadoRepository extends JpaRepository<MovimientoDetectado, UUID> {

    @Query("SELECT d FROM MovimientoDetectado d WHERE d.usuario.id = :usuarioId AND d.id = :id")
    Optional<MovimientoDetectado> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                                   @Param("id") UUID id);

    @Query("""
            SELECT count(d) > 0 FROM MovimientoDetectado d
             WHERE d.usuario.id = :usuarioId AND d.huella = :huella
            """)
    boolean existeHuella(@Param("usuarioId") UUID usuarioId, @Param("huella") String huella);

    @Query("""
            SELECT d FROM MovimientoDetectado d
             WHERE d.usuario.id = :usuarioId AND d.estado IN :estados
             ORDER BY d.fecha DESC NULLS LAST, d.hora DESC NULLS LAST, d.createdAt DESC
            """)
    List<MovimientoDetectado> listar(@Param("usuarioId") UUID usuarioId,
                                     @Param("estados") Collection<MovimientoDetectado.Estado> estados);

    /** Los que podrían ser el mismo movimiento: mismo banco, signo e importe, fecha cercana. */
    @Query("""
            SELECT d FROM MovimientoDetectado d
             WHERE d.usuario.id = :usuarioId AND d.banco = :banco AND d.monto = :monto
               AND d.entra = :entra AND d.fecha BETWEEN :desde AND :hasta
               AND d.estado <> com.axchisan.gastos.dominio.MovimientoDetectado.Estado.NO_RECONOCIDO
             ORDER BY d.createdAt
            """)
    List<MovimientoDetectado> parecidos(@Param("usuarioId") UUID usuarioId,
                                        @Param("banco") String banco,
                                        @Param("monto") BigDecimal monto,
                                        @Param("entra") boolean entra,
                                        @Param("desde") LocalDate desde,
                                        @Param("hasta") LocalDate hasta);

    /** Lo ya registrado que algún detectado reclamó como suyo. */
    @Query("""
            SELECT d.coincideId FROM MovimientoDetectado d
             WHERE d.usuario.id = :usuarioId AND d.coincideId IS NOT NULL
            """)
    List<UUID> registradosReclamados(@Param("usuarioId") UUID usuarioId);
}
