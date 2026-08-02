package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.AbonoDeuda;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AbonoDeudaRepository extends JpaRepository<AbonoDeuda, UUID> {

    @Query("SELECT a FROM AbonoDeuda a WHERE a.deuda.id = :deudaId ORDER BY a.fecha DESC")
    List<AbonoDeuda> listarDeLaDeuda(@Param("deudaId") UUID deudaId);

    @Query("SELECT a FROM AbonoDeuda a WHERE a.id = :id AND a.deuda.usuario.id = :usuarioId")
    Optional<AbonoDeuda> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    /** Abonos imputados a un mes; se descuentan del disponible. */
    @Query("SELECT coalesce(sum(a.monto), 0) FROM AbonoDeuda a WHERE a.mes.id = :mesId")
    BigDecimal totalDelMes(@Param("mesId") UUID mesId);

    @Query("SELECT a FROM AbonoDeuda a WHERE a.mes.id = :mesId ORDER BY a.fecha DESC")
    List<AbonoDeuda> listarDelMes(@Param("mesId") UUID mesId);
}
