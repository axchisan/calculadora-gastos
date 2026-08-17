package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.AliasTarjeta;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AliasTarjetaRepository extends JpaRepository<AliasTarjeta, UUID> {

    @Query("""
            SELECT a FROM AliasTarjeta a
             WHERE a.tarjeta.usuario.id = :usuarioId
             ORDER BY a.tarjeta.orden, a.createdAt
            """)
    List<AliasTarjeta> listarDelUsuario(@Param("usuarioId") UUID usuarioId);

    List<AliasTarjeta> findByTarjetaId(UUID tarjetaId);

    @Query("SELECT a FROM AliasTarjeta a WHERE a.tarjeta.usuario.id = :usuarioId AND a.id = :id")
    Optional<AliasTarjeta> buscarDelUsuario(@Param("usuarioId") UUID usuarioId,
                                            @Param("id") UUID id);

    /**
     * Comprueba si otro alias del usuario ya responde a ese apodo o a esos dígitos.
     *
     * <p>Sin esto, una compra capturada podría corresponder a dos tarjetas y acabaría en
     * cualquiera de ellas, que con débito y crédito de por medio no es un detalle menor.
     */
    @Query("""
            SELECT count(a) > 0 FROM AliasTarjeta a
             WHERE a.tarjeta.usuario.id = :usuarioId
               AND a.tarjeta.id <> :tarjetaId
               AND ((:aliasNorm IS NOT NULL AND a.aliasNorm = :aliasNorm)
                 OR (:ultimos4 IS NOT NULL AND a.ultimos4 = :ultimos4))
            """)
    boolean loUsaOtraTarjeta(@Param("usuarioId") UUID usuarioId,
                             @Param("tarjetaId") UUID tarjetaId,
                             @Param("aliasNorm") String aliasNorm,
                             @Param("ultimos4") String ultimos4);
}
