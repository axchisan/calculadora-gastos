package com.axchisan.gastos.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.Locale;
import java.util.UUID;

/** Persona que usa la aplicación. */
@Entity
@Table(name = "users")
public class Usuario {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String nombre;

    @Column(nullable = false)
    private String moneda = "COP";

    @Column(name = "zona_horaria", nullable = false)
    private String zonaHoraria = "America/Bogota";

    @Column(nullable = false)
    private boolean activo = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected Usuario() {
        // Requerido por JPA.
    }

    public Usuario(String email, String passwordHash, String nombre) {
        this.id = Identificadores.nuevo();
        this.email = normalizarEmail(email);
        this.passwordHash = passwordHash;
        this.nombre = nombre;
    }

    /**
     * Normaliza el correo a minúsculas y sin espacios.
     *
     * <p>La base de datos tiene un índice único sobre {@code lower(email)}, así que normalizar
     * aquí evita que la inserción falle por una diferencia de capitalización.
     */
    public static String normalizarEmail(String email) {
        return email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }

    @PrePersist
    void alCrear() {
        OffsetDateTime ahora = OffsetDateTime.now();
        this.createdAt = ahora;
        this.updatedAt = ahora;
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    @PreUpdate
    void alActualizar() {
        this.updatedAt = OffsetDateTime.now();
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = normalizarEmail(email);
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getMoneda() {
        return moneda;
    }

    public void setMoneda(String moneda) {
        this.moneda = moneda;
    }

    public String getZonaHoraria() {
        return zonaHoraria;
    }

    public void setZonaHoraria(String zonaHoraria) {
        this.zonaHoraria = zonaHoraria;
    }

    public boolean isActivo() {
        return activo;
    }

    public void setActivo(boolean activo) {
        this.activo = activo;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
