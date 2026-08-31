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
import java.time.YearMonth;
import java.util.UUID;

/**
 * Una cuota del cuadro de amortización, con los mismos conceptos que imprime el banco.
 *
 * <p>Se guardan por separado y no como un único total porque la gracia está en el reparto:
 * cuánto de lo que se paga mata deuda y cuánto se lo lleva el interés.
 */
@Entity
@Table(name = "credit_installments")
public class CuotaCredito {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "credit_id", nullable = false)
    private Credito credito;

    @Column(nullable = false)
    private short numero;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column
    private Short dias;

    /** Lo que se debe justo antes de pagar esta cuota. */
    @Column(name = "saldo_capital", nullable = false)
    private BigDecimal saldoCapital;

    @Column(nullable = false)
    private BigDecimal capital = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal interes = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal mora = BigDecimal.ZERO;

    /** Cargo fijo de la Ley Mipyme. Baja a mitad de plan, así que no es constante. */
    @Column(nullable = false)
    private BigDecimal mipyme = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal seguro = BigDecimal.ZERO;

    @Column(nullable = false)
    private BigDecimal otros = BigDecimal.ZERO;

    @Column(name = "valor_cuota", nullable = false)
    private BigDecimal valorCuota = BigDecimal.ZERO;

    @Column(nullable = false)
    private boolean pagada = false;

    @Column(name = "fecha_pago")
    private LocalDate fechaPago;

    @Column(name = "monto_pagado")
    private BigDecimal montoPagado;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected CuotaCredito() {
        // Requerido por JPA.
    }

    public CuotaCredito(int numero, LocalDate fecha, BigDecimal saldoCapital,
                        BigDecimal capital, BigDecimal interes, BigDecimal valorCuota) {
        this.id = Identificadores.nuevo();
        this.numero = (short) numero;
        this.fecha = fecha;
        this.saldoCapital = saldoCapital;
        this.capital = capital;
        this.interes = interes;
        this.valorCuota = valorCuota;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    /** Todo lo que no es capital ni interés: seguro, Mipyme, mora y demás. */
    public BigDecimal cargos() {
        return mipyme.add(seguro).add(otros).add(mora);
    }

    /** Mes al que se imputa esta cuota en el presupuesto. */
    public YearMonth periodo() {
        return YearMonth.from(fecha);
    }

    public void marcarPagada(LocalDate cuando, BigDecimal cuanto) {
        this.pagada = true;
        this.fechaPago = cuando == null ? LocalDate.now() : cuando;
        this.montoPagado = cuanto == null ? valorCuota : cuanto;
    }

    public void marcarPendiente() {
        this.pagada = false;
        this.fechaPago = null;
        this.montoPagado = null;
    }

    /** Si la cuota venció y sigue sin pagarse. */
    public boolean estaVencida(LocalDate hoy) {
        return !pagada && fecha.isBefore(hoy);
    }

    void asignarCredito(Credito credito) {
        this.credito = credito;
    }

    public UUID getId() {
        return id;
    }

    public Credito getCredito() {
        return credito;
    }

    public short getNumero() {
        return numero;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public Short getDias() {
        return dias;
    }

    public void setDias(Short dias) {
        this.dias = dias;
    }

    public BigDecimal getSaldoCapital() {
        return saldoCapital;
    }

    public BigDecimal getCapital() {
        return capital;
    }

    public BigDecimal getInteres() {
        return interes;
    }

    public BigDecimal getMora() {
        return mora;
    }

    public void setMora(BigDecimal mora) {
        this.mora = mora;
    }

    public BigDecimal getMipyme() {
        return mipyme;
    }

    public void setMipyme(BigDecimal mipyme) {
        this.mipyme = mipyme;
    }

    public BigDecimal getSeguro() {
        return seguro;
    }

    public void setSeguro(BigDecimal seguro) {
        this.seguro = seguro;
    }

    public BigDecimal getOtros() {
        return otros;
    }

    public void setOtros(BigDecimal otros) {
        this.otros = otros;
    }

    public BigDecimal getValorCuota() {
        return valorCuota;
    }

    public boolean isPagada() {
        return pagada;
    }

    public LocalDate getFechaPago() {
        return fechaPago;
    }

    public BigDecimal getMontoPagado() {
        return montoPagado;
    }
}
