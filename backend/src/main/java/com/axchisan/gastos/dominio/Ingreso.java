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

/**
 * Ingreso adicional al sueldo: primas, bonos o trabajos extra.
 *
 * <p>El campo {@code recibido} permite anotar dinero que aún no ha llegado, para distinguir entre
 * lo que ya está disponible y lo que se espera cobrar antes de fin de mes.
 */
@Entity
@Table(name = "incomes")
public class Ingreso {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "budget_month_id", nullable = false)
    private MesPresupuestal mes;

    @Column(nullable = false)
    private String concepto;

    @Column(nullable = false)
    private BigDecimal monto;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(nullable = false)
    private boolean recibido = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected Ingreso() {
        // Requerido por JPA.
    }

    public Ingreso(String concepto, BigDecimal monto, LocalDate fecha, boolean recibido) {
        this.id = Identificadores.nuevo();
        this.concepto = concepto;
        this.monto = monto;
        this.fecha = fecha;
        this.recibido = recibido;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    void asignarMes(MesPresupuestal mes) {
        this.mes = mes;
    }

    public UUID getId() {
        return id;
    }

    public MesPresupuestal getMes() {
        return mes;
    }

    public String getConcepto() {
        return concepto;
    }

    public void setConcepto(String concepto) {
        this.concepto = concepto;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public void setMonto(BigDecimal monto) {
        this.monto = monto;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public void setFecha(LocalDate fecha) {
        this.fecha = fecha;
    }

    public boolean isRecibido() {
        return recibido;
    }

    public void setRecibido(boolean recibido) {
        this.recibido = recibido;
    }
}
