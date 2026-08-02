package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.Gasto;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GastoRepository extends JpaRepository<Gasto, UUID> {

    /** Busca un gasto comprobando de paso que pertenece al usuario. */
    @Query("""
            SELECT g FROM Gasto g
             WHERE g.id = :id AND g.mes.usuario.id = :usuarioId
            """)
    Optional<Gasto> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    @Query("""
            SELECT g FROM Gasto g
             WHERE g.mes.id = :mesId
             ORDER BY g.orden ASC, g.nombre ASC
            """)
    List<Gasto> listarDelMes(@Param("mesId") UUID mesId);

    /** Gasto que refleja el resultado del cálculo de transporte, si ya se generó. */
    @Query("""
            SELECT g FROM Gasto g
             WHERE g.mes.id = :mesId AND g.origen = com.axchisan.gastos.dominio.OrigenGasto.TRANSPORTE
            """)
    Optional<Gasto> buscarGastoDeTransporte(@Param("mesId") UUID mesId);

    /** Totales por categoría del mes, para la gráfica de distribución. */
    @Query("""
            SELECT g.categoria, sum(g.monto)
              FROM Gasto g
             WHERE g.mes.id = :mesId
             GROUP BY g.categoria
             ORDER BY sum(g.monto) DESC
            """)
    List<Object[]> totalesPorCategoria(@Param("mesId") UUID mesId);

    @Query("SELECT coalesce(sum(g.monto), 0) FROM Gasto g WHERE g.mes.id = :mesId")
    BigDecimal totalDelMes(@Param("mesId") UUID mesId);

    @Query("SELECT coalesce(sum(g.montoPagado), 0) FROM Gasto g WHERE g.mes.id = :mesId")
    BigDecimal totalPagadoDelMes(@Param("mesId") UUID mesId);

    @Query("""
            SELECT coalesce(sum(g.monto), 0) FROM Gasto g
             WHERE g.mes.id = :mesId AND g.categoria = :categoria
            """)
    BigDecimal totalPorCategoria(@Param("mesId") UUID mesId,
                                 @Param("categoria") CategoriaGasto categoria);
}
