package com.axchisan.gastos.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Lo que se pagará de una deuda en una fecha, según el extracto (p. ej. el mínimo de una tarjeta). */
@Entity
@Table(name = "debt_schedule")
public class CuotaProgramada {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "debt_id", nullable = false)
    private Deuda deuda;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal monto;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected CuotaProgramada() {
        // Requerido por JPA.
    }

    public CuotaProgramada(Deuda deuda, LocalDate fecha, BigDecimal monto) {
        if (fecha == null || monto == null || monto.signum() <= 0) {
            throw new IllegalArgumentException("Cada cuota necesita fecha y un monto mayor que cero");
        }
        this.id = Identificadores.nuevo();
        this.deuda = deuda;
        this.fecha = fecha;
        this.monto = monto;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
    }

    public UUID getId() {
        return id;
    }

    public Deuda getDeuda() {
        return deuda;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public BigDecimal getMonto() {
        return monto;
    }
}
