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
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Deuda externa: tarjeta de crédito, préstamo, o dinero prestado por familiares o amigos. */
@Entity
@Table(name = "debts")
public class Deuda {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private String acreedor;

    @Column
    private String descripcion;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TipoDeuda tipo;

    @Column(name = "monto_original", nullable = false)
    private BigDecimal montoOriginal;

    @Column(nullable = false)
    private BigDecimal saldo;

    @Column(name = "tasa_interes_mensual")
    private BigDecimal tasaInteresMensual;

    @Column(name = "cuota_sugerida")
    private BigDecimal cuotaSugerida;

    @Column(name = "fecha_inicio", nullable = false)
    private LocalDate fechaInicio;

    @Column(name = "fecha_limite")
    private LocalDate fechaLimite;

    @Column(nullable = false)
    private boolean activa = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected Deuda() {
        // Requerido por JPA.
    }

    public Deuda(Usuario usuario, String acreedor, TipoDeuda tipo, BigDecimal montoOriginal,
                 LocalDate fechaInicio) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.acreedor = acreedor;
        this.tipo = tipo;
        this.montoOriginal = montoOriginal;
        this.saldo = montoOriginal;
        this.fechaInicio = fechaInicio;
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

    /**
     * Descuenta un abono del saldo.
     *
     * <p>Al llegar a cero, la deuda se marca como inactiva y deja de contar en el total adeudado.
     *
     * @throws IllegalArgumentException si el abono supera el saldo
     */
    public void abonar(BigDecimal importe) {
        if (importe == null || importe.signum() <= 0) {
            throw new IllegalArgumentException("El abono debe ser mayor que cero");
        }
        if (importe.compareTo(saldo) > 0) {
            throw new IllegalArgumentException(
                    "El abono supera el saldo de la deuda, que es " + saldo);
        }
        this.saldo = this.saldo.subtract(importe);
        if (this.saldo.signum() == 0) {
            this.activa = false;
        }
    }

    /** Revierte un abono, por ejemplo al eliminarlo. */
    public void revertirAbono(BigDecimal importe) {
        this.saldo = this.saldo.add(importe);
        if (this.saldo.signum() > 0) {
            this.activa = true;
        }
    }

    /** Porcentaje de la deuda ya saldado, entre 0 y 100. */
    public BigDecimal porcentajePagado() {
        if (montoOriginal.signum() == 0) {
            return BigDecimal.valueOf(100);
        }
        return montoOriginal.subtract(saldo)
                .multiply(BigDecimal.valueOf(100))
                .divide(montoOriginal, 2, RoundingMode.HALF_UP);
    }

    /**
     * Intereses que generará el saldo actual en un mes.
     *
     * <p>Devuelve cero si la deuda no tiene tasa, que es lo habitual en préstamos familiares.
     */
    public BigDecimal interesMensualEstimado() {
        if (tasaInteresMensual == null || tasaInteresMensual.signum() == 0) {
            return BigDecimal.ZERO;
        }
        return saldo.multiply(tasaInteresMensual)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    }

    public UUID getId() {
        return id;
    }

    public Usuario getUsuario() {
        return usuario;
    }

    public String getAcreedor() {
        return acreedor;
    }

    public void setAcreedor(String acreedor) {
        this.acreedor = acreedor;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public TipoDeuda getTipo() {
        return tipo;
    }

    public void setTipo(TipoDeuda tipo) {
        this.tipo = tipo;
    }

    public BigDecimal getMontoOriginal() {
        return montoOriginal;
    }

    public BigDecimal getSaldo() {
        return saldo;
    }

    public BigDecimal getTasaInteresMensual() {
        return tasaInteresMensual;
    }

    public void setTasaInteresMensual(BigDecimal tasaInteresMensual) {
        this.tasaInteresMensual = tasaInteresMensual;
    }

    public BigDecimal getCuotaSugerida() {
        return cuotaSugerida;
    }

    public void setCuotaSugerida(BigDecimal cuotaSugerida) {
        this.cuotaSugerida = cuotaSugerida;
    }

    public LocalDate getFechaInicio() {
        return fechaInicio;
    }

    public LocalDate getFechaLimite() {
        return fechaLimite;
    }

    public void setFechaLimite(LocalDate fechaLimite) {
        this.fechaLimite = fechaLimite;
    }

    public boolean isActiva() {
        return activa;
    }

    public void setActiva(boolean activa) {
        this.activa = activa;
    }
}
