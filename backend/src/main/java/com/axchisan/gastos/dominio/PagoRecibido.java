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
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.util.UUID;

/** Lo que de verdad llegó de un pago en otra moneda. */
@Entity
@Table(name = "income_payments")
public class PagoRecibido {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "source_id", nullable = false)
    private FuenteIngreso fuente;

    @Column(name = "mes_de_pago", nullable = false, length = 7)
    private String mesDePago;

    @Column(name = "monto_original", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoOriginal;

    @Column(name = "monto_pesos", nullable = false, precision = 14, scale = 2)
    private BigDecimal montoPesos;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected PagoRecibido() {
        // Requerido por JPA.
    }

    public PagoRecibido(FuenteIngreso fuente, YearMonth mesDePago, BigDecimal montoOriginal,
                        BigDecimal montoPesos, LocalDate fecha) {
        if (montoOriginal == null || montoOriginal.signum() <= 0
                || montoPesos == null || montoPesos.signum() <= 0) {
            throw new IllegalArgumentException("Los montos del pago deben ser mayores que cero");
        }
        this.id = Identificadores.nuevo();
        this.fuente = fuente;
        this.mesDePago = mesDePago.toString();
        this.montoOriginal = montoOriginal;
        this.montoPesos = montoPesos;
        this.fecha = fecha;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    /** Pesos que de verdad llegaron por cada unidad de la moneda original. */
    public BigDecimal tasaEfectiva() {
        return montoPesos.divide(montoOriginal, 2, RoundingMode.HALF_UP);
    }

    public void corregir(BigDecimal montoOriginal, BigDecimal montoPesos, LocalDate fecha) {
        if (montoOriginal.signum() <= 0 || montoPesos.signum() <= 0) {
            throw new IllegalArgumentException("Los montos del pago deben ser mayores que cero");
        }
        this.montoOriginal = montoOriginal;
        this.montoPesos = montoPesos;
        this.fecha = fecha;
    }

    public UUID getId() {
        return id;
    }

    public FuenteIngreso getFuente() {
        return fuente;
    }

    public YearMonth getMesDePago() {
        return YearMonth.parse(mesDePago);
    }

    public BigDecimal getMontoOriginal() {
        return montoOriginal;
    }

    public BigDecimal getMontoPesos() {
        return montoPesos;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
