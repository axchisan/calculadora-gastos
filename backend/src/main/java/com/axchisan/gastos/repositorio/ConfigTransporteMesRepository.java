package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.ConfigTransporteMes;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface ConfigTransporteMesRepository extends JpaRepository<ConfigTransporteMes, UUID> {

    @Query("SELECT c FROM ConfigTransporteMes c WHERE c.mes.id = :mesId")
    Optional<ConfigTransporteMes> buscarDelMes(@Param("mesId") UUID mesId);

    @Query("""
            SELECT c FROM ConfigTransporteMes c
             WHERE c.mes.id = :mesId AND c.mes.usuario.id = :usuarioId
            """)
    Optional<ConfigTransporteMes> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                                   @Param("mesId") UUID mesId);
}
