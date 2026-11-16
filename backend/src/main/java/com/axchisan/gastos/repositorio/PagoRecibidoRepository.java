package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.PagoRecibido;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PagoRecibidoRepository extends JpaRepository<PagoRecibido, UUID> {

    @Query("SELECT p FROM PagoRecibido p WHERE p.fuente.id = :fuenteId ORDER BY p.mesDePago DESC")
    List<PagoRecibido> deLaFuente(@Param("fuenteId") UUID fuenteId);

    @Query("SELECT p FROM PagoRecibido p WHERE p.fuente.id = :fuenteId AND p.mesDePago = :mes")
    Optional<PagoRecibido> delMes(@Param("fuenteId") UUID fuenteId, @Param("mes") String mes);
}
