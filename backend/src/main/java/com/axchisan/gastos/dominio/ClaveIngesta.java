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
 * Una clave con la que un dispositivo (el teléfono, el script de Gmail) envía avisos del banco
 * sin la sesión del usuario. Solo sirve para eso. Se guarda su huella, nunca la clave.
 */
@Entity
@Table(name = "ingest_keys")
public class ClaveIngesta {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false, length = 40)
    private String nombre;

    @Column(nullable = false, length = 64)
    private String huella;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "usada_en")
    private OffsetDateTime usadaEn;

    @Column(name = "revocada_en")
    private OffsetDateTime revocadaEn;

    protected ClaveIngesta() {
        // Requerido por JPA.
    }

    public ClaveIngesta(Usuario usuario, String nombre, String huella) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.nombre = nombre;
        this.huella = huella;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
    }

    public void registrarUso() {
        this.usadaEn = OffsetDateTime.now();
    }

    public void revocar() {
        if (revocadaEn == null) {
            this.revocadaEn = OffsetDateTime.now();
        }
    }

    public boolean isActiva() {
        return revocadaEn == null;
    }

    public UUID getId() {
        return id;
    }

    public Usuario getUsuario() {
        return usuario;
    }

    public String getNombre() {
        return nombre;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUsadaEn() {
        return usadaEn;
    }

    public OffsetDateTime getRevocadaEn() {
        return revocadaEn;
    }
}
