package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.MesPresupuestal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Meses del presupuesto.
 *
 * <p>Todas las consultas incluyen el usuario en el filtro: es lo que impide que alguien acceda al
 * mes de otra persona conociendo su identificador.
 */
public interface MesPresupuestalRepository extends JpaRepository<MesPresupuestal, UUID> {

    @Query("""
            SELECT m FROM MesPresupuestal m
             WHERE m.usuario.id = :usuarioId AND m.anio = :anio AND m.mes = :mes
            """)
    Optional<MesPresupuestal> buscarPorPeriodo(@Param("usuarioId") UUID usuarioId,
                                               @Param("anio") short anio,
                                               @Param("mes") short mes);

    @Query("""
            SELECT m FROM MesPresupuestal m
             WHERE m.usuario.id = :usuarioId AND m.id = :id
            """)
    Optional<MesPresupuestal> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                               @Param("id") UUID id);

    @Query("""
            SELECT m FROM MesPresupuestal m
             WHERE m.usuario.id = :usuarioId
             ORDER BY m.anio DESC, m.mes DESC
            """)
    List<MesPresupuestal> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    /** Meses desde un periodo dado en adelante, en orden cronológico, para las gráficas. */
    @Query("""
            SELECT m FROM MesPresupuestal m
             WHERE m.usuario.id = :usuarioId
               AND (m.anio > :anio OR (m.anio = :anio AND m.mes >= :mes))
             ORDER BY m.anio ASC, m.mes ASC
            """)
    List<MesPresupuestal> listarDesde(@Param("usuarioId") UUID usuarioId,
                                      @Param("anio") short anio,
                                      @Param("mes") short mes);

    @Query("""
            SELECT count(m) > 0 FROM MesPresupuestal m
             WHERE m.usuario.id = :usuarioId AND m.anio = :anio AND m.mes = :mes
            """)
    boolean existePeriodo(@Param("usuarioId") UUID usuarioId,
                          @Param("anio") short anio,
                          @Param("mes") short mes);
}
