package com.axchisan.gastos.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Token de refresco emitido al iniciar sesión.
 *
 * <p>Nunca se almacena el token en claro, solo su hash SHA-256: si la base de datos se filtra,
 * los tokens siguen sin poder usarse.
 *
 * <p>Cada inicio de sesión abre una <b>familia</b>. Al renovar, el token usado se marca y se
 * emite uno nuevo en la misma familia. Si llega un token ya consumido, significa que alguien
 * está reutilizando uno robado, y se revoca la familia entera.
 */
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(name = "token_hash", nullable = false, length = 64)
    private String tokenHash;

    @Column(nullable = false)
    private UUID familia;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;

    @Column(name = "revoked_at")
    private OffsetDateTime revokedAt;

    @Column(name = "used_at")
    private OffsetDateTime usedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected RefreshToken() {
        // Requerido por JPA.
    }

    public RefreshToken(Usuario usuario, String tokenHash, UUID familia, OffsetDateTime expiresAt) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.tokenHash = tokenHash;
        this.familia = familia;
        this.expiresAt = expiresAt;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    /** Indica si el token sigue siendo utilizable. */
    public boolean estaVigente() {
        return revokedAt == null
                && usedAt == null
                && expiresAt.isAfter(OffsetDateTime.now());
    }

    /** Indica si ya se usó: recibirlo de nuevo delata que fue robado. */
    public boolean fueUsado() {
        return usedAt != null;
    }

    /** Marca el token como consumido al rotarlo. */
    public void marcarUsado() {
        this.usedAt = OffsetDateTime.now();
    }

    /** Revoca el token, por cierre de sesión o por sospecha de robo. */
    public void revocar() {
        if (this.revokedAt == null) {
            this.revokedAt = OffsetDateTime.now();
        }
    }

    public UUID getId() {
        return id;
    }

    public Usuario getUsuario() {
        return usuario;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public UUID getFamilia() {
        return familia;
    }

    public OffsetDateTime getExpiresAt() {
        return expiresAt;
    }

    public OffsetDateTime getRevokedAt() {
        return revokedAt;
    }

    public OffsetDateTime getUsedAt() {
        return usedAt;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
