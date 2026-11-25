package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.CuotaProgramada;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface CuotaProgramadaRepository extends JpaRepository<CuotaProgramada, UUID> {

    @Query("SELECT c FROM CuotaProgramada c WHERE c.deuda.id = :deudaId ORDER BY c.fecha")
    List<CuotaProgramada> deLaDeuda(@Param("deudaId") UUID deudaId);

    @Modifying
    @Query("DELETE FROM CuotaProgramada c WHERE c.deuda.id = :deudaId")
    void borrarDeLaDeuda(@Param("deudaId") UUID deudaId);
}
