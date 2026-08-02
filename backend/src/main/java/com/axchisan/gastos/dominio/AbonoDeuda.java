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

/** Pago realizado a una deuda. */
@Entity
@Table(name = "debt_payments")
public class AbonoDeuda {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "debt_id", nullable = false)
    private Deuda deuda;

    /** Mes al que se imputa el abono; puede quedar sin vincular. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "budget_month_id")
    private MesPresupuestal mes;

    @Column(nullable = false)
    private BigDecimal monto;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column
    private String nota;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected AbonoDeuda() {
        // Requerido por JPA.
    }

    public AbonoDeuda(Deuda deuda, MesPresupuestal mes, BigDecimal monto, LocalDate fecha) {
        this.id = Identificadores.nuevo();
        this.deuda = deuda;
        this.mes = mes;
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

    public UUID getId() {
        return id;
    }

    public Deuda getDeuda() {
        return deuda;
    }

    public MesPresupuestal getMes() {
        return mes;
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
