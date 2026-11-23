package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.ClaveIngesta;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ClaveIngestaRepository extends JpaRepository<ClaveIngesta, UUID> {

    @Query("""
            SELECT c FROM ClaveIngesta c
             WHERE c.usuario.id = :usuarioId AND c.revocadaEn IS NULL
             ORDER BY c.createdAt
            """)
    List<ClaveIngesta> activasDelUsuario(@Param("usuarioId") UUID usuarioId);

    @Query("SELECT c FROM ClaveIngesta c WHERE c.usuario.id = :usuarioId AND c.id = :id")
    Optional<ClaveIngesta> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                            @Param("id") UUID id);

    @Query("""
            SELECT c FROM ClaveIngesta c JOIN FETCH c.usuario
             WHERE c.huella = :huella AND c.revocadaEn IS NULL
            """)
    Optional<ClaveIngesta> buscarActivaPorHuella(@Param("huella") String huella);
}
