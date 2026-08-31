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
}
