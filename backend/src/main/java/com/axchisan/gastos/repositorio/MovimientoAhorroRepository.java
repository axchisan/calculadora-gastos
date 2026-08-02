package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.MovimientoAhorro;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MovimientoAhorroRepository extends JpaRepository<MovimientoAhorro, UUID> {

    @Query("SELECT m FROM MovimientoAhorro m WHERE m.meta.id = :metaId ORDER BY m.fecha DESC")
    List<MovimientoAhorro> listarDeLaMeta(@Param("metaId") UUID metaId);

    @Query("SELECT m FROM MovimientoAhorro m WHERE m.id = :id AND m.meta.usuario.id = :usuarioId")
    Optional<MovimientoAhorro> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                                @Param("id") UUID id);

    @Query("SELECT m FROM MovimientoAhorro m WHERE m.mes.id = :mesId ORDER BY m.fecha DESC")
    List<MovimientoAhorro> listarDelMes(@Param("mesId") UUID mesId);

    /**
     * Aporte neto del mes: los aportes menos los retiros.
     *
     * <p>Puede ser negativo si en el mes se retiró más de lo que se aportó.
     */
    @Query("""
            SELECT coalesce(sum(
                     CASE WHEN m.tipo = com.axchisan.gastos.dominio.TipoMovimientoAhorro.APORTE
                          THEN m.monto ELSE -m.monto END), 0)
              FROM MovimientoAhorro m
             WHERE m.mes.id = :mesId
            """)
    BigDecimal aporteNetoDelMes(@Param("mesId") UUID mesId);
}
