package com.axchisan.gastos.dominio;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Un mes del presupuesto: la unidad alrededor de la que gira toda la aplicación.
 *
 * <p>Cada mes guarda su propio sueldo y sus propios gastos. Cambiar el ingreso de septiembre no
 * altera agosto, que es lo que permite conservar el histórico para las gráficas.
 */
@Entity
@Table(name = "budget_months")
public class MesPresupuestal {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private short anio;

    @Column(nullable = false)
    private short mes;

    @Column(name = "ingreso_base", nullable = false)
    private BigDecimal ingresoBase = BigDecimal.ZERO;

    @Column(nullable = false)
    private boolean cerrado = false;

    @Column
    private String notas;

    @OneToMany(mappedBy = "mes", cascade = CascadeType.ALL, orphanRemoval = true,
            fetch = FetchType.LAZY)
    @OrderBy("orden ASC, nombre ASC")
    private List<Gasto> gastos = new ArrayList<>();

    @OneToMany(mappedBy = "mes", cascade = CascadeType.ALL, orphanRemoval = true,
            fetch = FetchType.LAZY)
    @OrderBy("fecha ASC")
    private List<Ingreso> ingresos = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected MesPresupuestal() {
        // Requerido por JPA.
    }

    public MesPresupuestal(Usuario usuario, YearMonth periodo, BigDecimal ingresoBase) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.anio = (short) periodo.getYear();
        this.mes = (short) periodo.getMonthValue();
        this.ingresoBase = ingresoBase == null ? BigDecimal.ZERO : ingresoBase;
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

    public YearMonth periodo() {
        return YearMonth.of(anio, mes);
    }

    /** Añade un gasto manteniendo la relación en ambos sentidos. */
    public void agregarGasto(Gasto gasto) {
        gastos.add(gasto);
        gasto.asignarMes(this);
    }

    /** Añade un ingreso adicional manteniendo la relación en ambos sentidos. */
    public void agregarIngreso(Ingreso ingreso) {
        ingresos.add(ingreso);
        ingreso.asignarMes(this);
    }

    public UUID getId() {
        return id;
    }

    public Usuario getUsuario() {
        return usuario;
    }

    public short getAnio() {
        return anio;
    }

    public short getMes() {
        return mes;
    }

    public BigDecimal getIngresoBase() {
        return ingresoBase;
    }

    public void setIngresoBase(BigDecimal ingresoBase) {
        this.ingresoBase = ingresoBase;
    }

    public boolean isCerrado() {
        return cerrado;
    }

    public void setCerrado(boolean cerrado) {
        this.cerrado = cerrado;
    }

    public String getNotas() {
        return notas;
    }

    public void setNotas(String notas) {
        this.notas = notas;
    }

    public List<Gasto> getGastos() {
        return gastos;
    }

    public List<Ingreso> getIngresos() {
        return ingresos;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
