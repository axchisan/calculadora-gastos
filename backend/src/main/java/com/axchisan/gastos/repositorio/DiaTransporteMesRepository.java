package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.DiaTransporteMes;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DiaTransporteMesRepository extends JpaRepository<DiaTransporteMes, UUID> {

    @Query("SELECT d FROM DiaTransporteMes d WHERE d.mes.id = :mesId ORDER BY d.fecha ASC")
    List<DiaTransporteMes> listarDelMes(@Param("mesId") UUID mesId);

    @Query("SELECT d FROM DiaTransporteMes d WHERE d.id = :id AND d.mes.usuario.id = :usuarioId")
    Optional<DiaTransporteMes> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                                @Param("id") UUID id);

    /** Borra los días del mes antes de regenerarlos desde cero. */
    @Modifying
    @Query("DELETE FROM DiaTransporteMes d WHERE d.mes.id = :mesId")
    int borrarDelMes(@Param("mesId") UUID mesId);
}
