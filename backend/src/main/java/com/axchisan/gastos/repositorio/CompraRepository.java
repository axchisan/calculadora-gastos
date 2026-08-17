package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.Compra;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CompraRepository extends JpaRepository<Compra, UUID> {

    @Query("""
            SELECT c FROM Compra c
             LEFT JOIN FETCH c.tarjeta
             WHERE c.mes.id = :mesId
             ORDER BY c.fecha DESC, c.createdAt DESC
            """)
    List<Compra> listarDelMes(@Param("mesId") UUID mesId);

    @Query("""
            SELECT c FROM Compra c
             LEFT JOIN FETCH c.tarjeta
             WHERE c.mes.usuario.id = :usuarioId AND c.id = :id
            """)
    Optional<Compra> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    /** Todo lo comprado en el mes, se haya pagado ya o quede a deber en la tarjeta. */
    @Query("SELECT coalesce(sum(c.monto), 0) FROM Compra c WHERE c.mes.id = :mesId")
    BigDecimal totalDelMes(@Param("mesId") UUID mesId);

    /**
     * Lo comprado en el mes que salió del bolsillo en el acto.
     *
     * <p>Es la parte que reduce el dinero disponible hoy; lo que se cargó a una tarjeta de
     * crédito no lo hace hasta que vence su corte.
     */
    @Query("""
            SELECT coalesce(sum(c.monto), 0) FROM Compra c
             WHERE c.mes.id = :mesId AND c.medio <> 'CREDITO'
            """)
    BigDecimal totalInmediatoDelMes(@Param("mesId") UUID mesId);

    /** Lo cargado a tarjetas de crédito durante el mes, que se pagará más adelante. */
    @Query("""
            SELECT coalesce(sum(c.monto), 0) FROM Compra c
             WHERE c.mes.id = :mesId AND c.medio = 'CREDITO'
            """)
    BigDecimal totalACreditoDelMes(@Param("mesId") UUID mesId);

    /**
     * Lo que vence en un periodo por cortes de tarjeta y aún no se ha pagado.
     *
     * <p>Se cruza por usuario y no por mes, porque lo que vence en octubre está repartido entre
     * las compras de agosto y las de septiembre.
     */
    @Query("""
            SELECT coalesce(sum(c.monto), 0) FROM Compra c
             WHERE c.mes.usuario.id = :usuarioId
               AND c.medio = 'CREDITO'
               AND c.pagoAnio = :anio AND c.pagoMes = :mes
               AND c.pagado = false
            """)
    BigDecimal cortesPendientesDe(@Param("usuarioId") UUID usuarioId,
                                  @Param("anio") short anio, @Param("mes") short mes);

    /** Cortes de tarjeta que vencían en el periodo y ya se pagaron. */
    @Query("""
            SELECT coalesce(sum(c.monto), 0) FROM Compra c
             WHERE c.mes.usuario.id = :usuarioId
               AND c.medio = 'CREDITO'
               AND c.pagoAnio = :anio AND c.pagoMes = :mes
               AND c.pagado = true
            """)
    BigDecimal cortesPagadosDe(@Param("usuarioId") UUID usuarioId,
                               @Param("anio") short anio, @Param("mes") short mes);

    /** Las compras a crédito que vencen en un periodo, para poder saldar el corte entero. */
    @Query("""
            SELECT c FROM Compra c
             LEFT JOIN FETCH c.tarjeta
             WHERE c.mes.usuario.id = :usuarioId
               AND c.medio = 'CREDITO'
               AND c.pagoAnio = :anio AND c.pagoMes = :mes
             ORDER BY c.fecha
            """)
    List<Compra> cortesDe(@Param("usuarioId") UUID usuarioId,
                          @Param("anio") short anio, @Param("mes") short mes);

    /** Suma por categoría de lo comprado en el mes, para la gráfica de distribución. */
    @Query("""
            SELECT c.categoria, sum(c.monto) FROM Compra c
             WHERE c.mes.id = :mesId
             GROUP BY c.categoria
             ORDER BY sum(c.monto) DESC
            """)
    List<Object[]> totalesPorCategoria(@Param("mesId") UUID mesId);

    /** Cuánto se lleva gastado por día, para ver el ritmo del mes. */
    @Query("""
            SELECT c.fecha, sum(c.monto) FROM Compra c
             WHERE c.mes.id = :mesId
             GROUP BY c.fecha
             ORDER BY c.fecha
            """)
    List<Object[]> totalesPorDia(@Param("mesId") UUID mesId);

    /** Descripciones ya usadas, para sugerirlas al escribir una compra nueva. */
    @Query("""
            SELECT c.descripcion, c.categoria, count(c) FROM Compra c
             WHERE c.mes.usuario.id = :usuarioId
             GROUP BY c.descripcion, c.categoria
             ORDER BY count(c) DESC, max(c.fecha) DESC
            """)
    List<Object[]> descripcionesFrecuentes(@Param("usuarioId") UUID usuarioId);

    long countByTarjetaId(UUID tarjetaId);
}
