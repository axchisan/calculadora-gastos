package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.Ingreso;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface IngresoRepository extends JpaRepository<Ingreso, UUID> {

    @Query("SELECT i FROM Ingreso i WHERE i.mes.id = :mesId ORDER BY i.fecha ASC")
    List<Ingreso> listarDelMes(@Param("mesId") UUID mesId);

    @Query("SELECT i FROM Ingreso i WHERE i.id = :id AND i.mes.usuario.id = :usuarioId")
    Optional<Ingreso> buscarDelUsuario(@Param("usuarioId") UUID usuarioId, @Param("id") UUID id);

    /** Suma solo lo ya cobrado: es lo que está realmente disponible. */
    @Query("""
            SELECT coalesce(sum(i.monto), 0) FROM Ingreso i
             WHERE i.mes.id = :mesId AND i.recibido = true
            """)
    BigDecimal totalRecibidoDelMes(@Param("mesId") UUID mesId);

    /** Suma todo lo previsto, cobrado o no, para proyectar el cierre del mes. */
    @Query("SELECT coalesce(sum(i.monto), 0) FROM Ingreso i WHERE i.mes.id = :mesId")
    BigDecimal totalPrevistoDelMes(@Param("mesId") UUID mesId);
}
