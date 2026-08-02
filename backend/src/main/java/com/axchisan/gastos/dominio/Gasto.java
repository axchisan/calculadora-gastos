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
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Un gasto concreto dentro de un mes.
 *
 * <p>El estado y el importe abonado se mantienen siempre coherentes entre sí a través de los
 * métodos de esta clase; la base de datos lo verifica además con una restricción, de modo que un
 * error de programación no puede dejar un gasto marcado como pagado con un abono menor.
 */
@Entity
@Table(name = "expenses")
public class Gasto {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "budget_month_id", nullable = false)
    private MesPresupuestal mes;

    /** Plantilla de la que proviene, si se generó al crear el mes. */
    @Column(name = "template_id")
    private UUID plantillaId;

    @Column(nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CategoriaGasto categoria;

    @Column(nullable = false)
    private BigDecimal monto = BigDecimal.ZERO;

    @Column(name = "monto_pagado", nullable = false)
    private BigDecimal montoPagado = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EstadoGasto estado = EstadoGasto.PENDIENTE;

    @Column(name = "fecha_pago")
    private LocalDate fechaPago;

    @Column(name = "dia_vencimiento")
    private Short diaVencimiento;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrigenGasto origen = OrigenGasto.MANUAL;

    @Column
    private String notas;

    @Column(nullable = false)
    private short orden = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected Gasto() {
        // Requerido por JPA.
    }

    public Gasto(String nombre, CategoriaGasto categoria, BigDecimal monto, OrigenGasto origen) {
        this.id = Identificadores.nuevo();
        this.nombre = nombre;
        this.categoria = categoria;
        this.monto = monto == null ? BigDecimal.ZERO : monto;
        this.origen = origen;
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

    /** Lo que falta por pagar. */
    public BigDecimal saldoPendiente() {
        return monto.subtract(montoPagado);
    }

    /** Marca el gasto como saldado por completo. */
    public void marcarPagado(LocalDate fecha) {
        this.montoPagado = this.monto;
        this.estado = EstadoGasto.PAGADO;
        this.fechaPago = fecha == null ? LocalDate.now() : fecha;
    }

    /** Deshace el pago y vuelve el gasto a pendiente. */
    public void marcarPendiente() {
        this.montoPagado = BigDecimal.ZERO;
        this.estado = EstadoGasto.PENDIENTE;
        this.fechaPago = null;
    }

    /**
     * Registra un abono parcial.
     *
     * @throws IllegalArgumentException si el abono es negativo o supera el saldo pendiente
     */
    public void abonar(BigDecimal importe, LocalDate fecha) {
        if (importe == null || importe.signum() <= 0) {
            throw new IllegalArgumentException("El abono debe ser mayor que cero");
        }
        if (importe.compareTo(saldoPendiente()) > 0) {
            throw new IllegalArgumentException(
                    "El abono supera el saldo pendiente del gasto, que es " + saldoPendiente());
        }
        this.montoPagado = this.montoPagado.add(importe);
        this.fechaPago = fecha == null ? LocalDate.now() : fecha;
        recalcularEstado();
    }

    /**
     * Cambia el importe del gasto.
     *
     * <p>Si el nuevo importe queda por debajo de lo ya abonado, el gasto pasa a estar pagado por
     * completo: no tendría sentido conservar un abono superior al valor del gasto, y la base de
     * datos lo rechazaría.
     */
    public void cambiarMonto(BigDecimal nuevoMonto) {
        if (nuevoMonto == null || nuevoMonto.signum() < 0) {
            throw new IllegalArgumentException("El monto no puede ser negativo");
        }
        this.monto = nuevoMonto;
        if (this.montoPagado.compareTo(nuevoMonto) > 0) {
            this.montoPagado = nuevoMonto;
        }
        recalcularEstado();
    }

    private void recalcularEstado() {
        if (montoPagado.signum() == 0) {
            this.estado = EstadoGasto.PENDIENTE;
            this.fechaPago = null;
        } else if (montoPagado.compareTo(monto) >= 0) {
            this.estado = EstadoGasto.PAGADO;
        } else {
            this.estado = EstadoGasto.PARCIAL;
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

    public UUID getPlantillaId() {
        return plantillaId;
    }

    public void setPlantillaId(UUID plantillaId) {
        this.plantillaId = plantillaId;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public CategoriaGasto getCategoria() {
        return categoria;
    }

    public void setCategoria(CategoriaGasto categoria) {
        this.categoria = categoria;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public BigDecimal getMontoPagado() {
        return montoPagado;
    }

    public EstadoGasto getEstado() {
        return estado;
    }

    public LocalDate getFechaPago() {
        return fechaPago;
    }

    public Short getDiaVencimiento() {
        return diaVencimiento;
    }

    public void setDiaVencimiento(Short diaVencimiento) {
        this.diaVencimiento = diaVencimiento;
    }

    public OrigenGasto getOrigen() {
        return origen;
    }

    public String getNotas() {
        return notas;
    }

    public void setNotas(String notas) {
        this.notas = notas;
    }

    public short getOrden() {
        return orden;
    }

    public void setOrden(short orden) {
        this.orden = orden;
    }
}
