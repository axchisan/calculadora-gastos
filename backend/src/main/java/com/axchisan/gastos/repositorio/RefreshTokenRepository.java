package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /**
     * Revoca de golpe todos los tokens de una familia.
     *
     * <p>Se invoca al detectar que se reutilizó un token ya consumido: no se sabe si el legítimo
     * es quien lo presenta o quien lo robó, así que se cierra la sesión entera.
     */
    @Modifying
    @Query("""
            UPDATE RefreshToken t
               SET t.revokedAt = :ahora
             WHERE t.familia = :familia
               AND t.revokedAt IS NULL
            """)
    int revocarFamilia(@Param("familia") UUID familia, @Param("ahora") OffsetDateTime ahora);

    /** Revoca todas las sesiones abiertas de un usuario. */
    @Modifying
    @Query("""
            UPDATE RefreshToken t
               SET t.revokedAt = :ahora
             WHERE t.usuario.id = :usuarioId
               AND t.revokedAt IS NULL
            """)
    int revocarTodosDelUsuario(@Param("usuarioId") UUID usuarioId,
                               @Param("ahora") OffsetDateTime ahora);

    /** Elimina los tokens caducados; se ejecuta periódicamente para no acumular basura. */
    @Modifying
    @Query("DELETE FROM RefreshToken t WHERE t.expiresAt < :limite")
    int eliminarCaducados(@Param("limite") OffsetDateTime limite);
}
