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

    /**
     * Cuota, saldo y lo ya abonado este mes de cada deuda activa con cuota definida.
     *
     * <p>Sirve para proyectar cuánto del sueldo se irá en deudas antes de que ocurra. Se
     * devuelven los tres valores porque lo que queda por pagar este mes es la cuota menos lo ya
     * abonado, y nunca más que el saldo pendiente.
     */
    @Query("""
            SELECT d.cuotaSugerida, d.saldo,
                   coalesce((SELECT sum(a.monto) FROM AbonoDeuda a
                              WHERE a.deuda = d AND a.mes.id = :mesId), 0)
              FROM Deuda d
             WHERE d.usuario.id = :usuarioId
               AND d.activa = true
               AND d.cuotaSugerida IS NOT NULL
               AND d.cuotaSugerida > 0
            """)
    List<Object[]> cuotasPrevistas(@Param("usuarioId") UUID usuarioId, @Param("mesId") UUID mesId);

    /**
     * Deudas activas sin cuota mensual.
     *
     * <p>No se pueden proyectar: sin saber cuánto se piensa abonar cada mes, no hay forma de
     * estimar qué parte del sueldo ocuparán. La aplicación lo advierte en lugar de ignorarlas
     * en silencio.
     */
    @Query("""
            SELECT count(d) FROM Deuda d
             WHERE d.usuario.id = :usuarioId
               AND d.activa = true
               AND (d.cuotaSugerida IS NULL OR d.cuotaSugerida = 0)
            """)
    long contarSinCuota(@Param("usuarioId") UUID usuarioId);
}
