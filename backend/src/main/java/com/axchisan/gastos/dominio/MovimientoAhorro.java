package com.axchisan.gastos.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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

/** Aporte o retiro sobre una meta de ahorro. */
@Entity
@Table(name = "savings_movements")
public class MovimientoAhorro {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "savings_goal_id", nullable = false)
    private MetaAhorro meta;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "budget_month_id")
    private MesPresupuestal mes;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TipoMovimientoAhorro tipo;

    @Column(nullable = false)
    private BigDecimal monto;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column
    private String nota;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected MovimientoAhorro() {
        // Requerido por JPA.
    }

    public MovimientoAhorro(MetaAhorro meta, MesPresupuestal mes, TipoMovimientoAhorro tipo,
                            BigDecimal monto, LocalDate fecha) {
        this.id = Identificadores.nuevo();
        this.meta = meta;
        this.mes = mes;
        this.tipo = tipo;
        this.monto = monto;
        this.fecha = fecha;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    /** Importe con signo: positivo si aporta, negativo si retira. */
    public BigDecimal montoConSigno() {
        return tipo == TipoMovimientoAhorro.APORTE ? monto : monto.negate();
    }

    public UUID getId() {
        return id;
    }

    public MetaAhorro getMeta() {
        return meta;
    }

    public MesPresupuestal getMes() {
        return mes;
    }

    public TipoMovimientoAhorro getTipo() {
        return tipo;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public String getNota() {
        return nota;
    }

    public void setNota(String nota) {
        this.nota = nota;
    }
}
