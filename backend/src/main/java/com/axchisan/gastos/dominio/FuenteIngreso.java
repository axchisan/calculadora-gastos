package com.axchisan.gastos.dominio;

import com.axchisan.gastos.sueldo.CondicionesCobro;
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
 * Un ingreso recurrente cobrado en otra moneda, como un contrato de prestación de servicios
 * pagado en dólares.
 *
 * <p>Guarda lo pactado (cuánto, desde cuándo, en qué días se paga) y lo que hace falta para
 * pasarlo a pesos: la TRM de referencia y los costos del medio por el que llega.
 */
@Entity
@Table(name = "income_sources")
public class FuenteIngreso {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private String nombre;

    @Column(nullable = false, length = 3)
    private String moneda = "USD";

    @Column(name = "monto_mensual", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoMensual;

    @Column(name = "fecha_inicio", nullable = false)
    private LocalDate fechaInicio;

    @Column(name = "fecha_fin")
    private LocalDate fechaFin;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private MedioCobro medio = MedioCobro.TRANSFERENCIA;

    @Column(name = "cuenta_destino")
    private String cuentaDestino;

    @Column(name = "dias_habiles_pago", nullable = false)
    private short diasHabilesPago = 5;

    @Column(name = "dias_tolerancia", nullable = false)
    private short diasTolerancia = 2;

    @Column(name = "trm_referencia", nullable = false, precision = 10, scale = 2)
    private BigDecimal trmReferencia;

    @Column(name = "trm_fecha", nullable = false)
    private LocalDate trmFecha;

    @Column(name = "trm_automatica", nullable = false)
    private boolean trmAutomatica = true;

    @Column(name = "comision_porcentaje", nullable = false, precision = 5, scale = 2)
    private BigDecimal comisionPorcentaje = BigDecimal.ZERO;

    @Column(name = "comision_fija", nullable = false, precision = 8, scale = 2)
    private BigDecimal comisionFija = BigDecimal.ZERO;

    @Column(name = "descuento_cambio_porcentaje", nullable = false, precision = 5, scale = 2)
    private BigDecimal descuentoCambioPorcentaje = BigDecimal.ZERO;

    @Column(name = "costo_retiro", nullable = false, precision = 10, scale = 2)
    private BigDecimal costoRetiro = BigDecimal.ZERO;

    @Column(nullable = false)
    private boolean activo = true;

    @Column
    private String notas;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected FuenteIngreso() {
        // Requerido por JPA.
    }

    public FuenteIngreso(Usuario usuario, String nombre, BigDecimal montoMensual,
                         LocalDate fechaInicio, BigDecimal trmReferencia, LocalDate trmFecha) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.nombre = nombre;
        this.montoMensual = montoMensual;
        this.fechaInicio = fechaInicio;
        this.trmReferencia = trmReferencia;
        this.trmFecha = trmFecha;
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

    /** Las condiciones con las que se calcula cada pago. */
    public CondicionesCobro condiciones() {
        return new CondicionesCobro(montoMensual, fechaInicio, fechaFin, medio, diasHabilesPago,
                diasTolerancia, trmReferencia, comisionPorcentaje, comisionFija,
                descuentoCambioPorcentaje, costoRetiro);
    }

    /**
     * Aplica los costos típicos del medio elegido.
     *
     * <p>PayPal cobra 5,4 % + 0,30 USD por recibir un pago internacional, convierte alrededor de
     * un 3,5 % por debajo de la TRM y retirar a un banco colombiano cuesta unos 3.500 pesos. Una
     * transferencia directa en pesos llega a la TRM del día sin descuentos.
     */
    public void usarCostosTipicosDe(MedioCobro medio) {
        this.medio = medio;
        if (medio == MedioCobro.PAYPAL) {
            this.comisionPorcentaje = new BigDecimal("5.40");
            this.comisionFija = new BigDecimal("0.30");
            this.descuentoCambioPorcentaje = new BigDecimal("3.50");
            this.costoRetiro = new BigDecimal("3500");
        } else {
            this.comisionPorcentaje = BigDecimal.ZERO;
            this.comisionFija = BigDecimal.ZERO;
            this.descuentoCambioPorcentaje = BigDecimal.ZERO;
            this.costoRetiro = BigDecimal.ZERO;
        }
    }

    public void actualizarTrm(BigDecimal trm, LocalDate fecha) {
        if (trm == null || trm.signum() <= 0) {
            throw new IllegalArgumentException("La TRM debe ser mayor que cero");
        }
        this.trmReferencia = trm;
        this.trmFecha = fecha != null ? fecha : LocalDate.now();
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

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getMoneda() {
        return moneda;
    }

    public BigDecimal getMontoMensual() {
        return montoMensual;
    }

    public void setMontoMensual(BigDecimal montoMensual) {
        this.montoMensual = montoMensual;
    }

    public LocalDate getFechaInicio() {
        return fechaInicio;
    }

    public void setFechaInicio(LocalDate fechaInicio) {
        this.fechaInicio = fechaInicio;
    }

    public LocalDate getFechaFin() {
        return fechaFin;
    }

    public void setFechaFin(LocalDate fechaFin) {
        this.fechaFin = fechaFin;
    }

    public MedioCobro getMedio() {
        return medio;
    }

    public String getCuentaDestino() {
        return cuentaDestino;
    }

    public void setCuentaDestino(String cuentaDestino) {
        this.cuentaDestino = cuentaDestino;
    }

    public short getDiasHabilesPago() {
        return diasHabilesPago;
    }

    public void setDiasHabilesPago(short diasHabilesPago) {
        this.diasHabilesPago = diasHabilesPago;
    }

    public short getDiasTolerancia() {
        return diasTolerancia;
    }

    public void setDiasTolerancia(short diasTolerancia) {
        this.diasTolerancia = diasTolerancia;
    }

    public BigDecimal getTrmReferencia() {
        return trmReferencia;
    }

    public LocalDate getTrmFecha() {
        return trmFecha;
    }

    public boolean isTrmAutomatica() {
        return trmAutomatica;
    }

    public void setTrmAutomatica(boolean trmAutomatica) {
        this.trmAutomatica = trmAutomatica;
    }

    public BigDecimal getComisionPorcentaje() {
        return comisionPorcentaje;
    }

    public void setComisionPorcentaje(BigDecimal comisionPorcentaje) {
        this.comisionPorcentaje = comisionPorcentaje;
    }

    public BigDecimal getComisionFija() {
        return comisionFija;
    }

    public void setComisionFija(BigDecimal comisionFija) {
        this.comisionFija = comisionFija;
    }

    public BigDecimal getDescuentoCambioPorcentaje() {
        return descuentoCambioPorcentaje;
    }

    public void setDescuentoCambioPorcentaje(BigDecimal descuentoCambioPorcentaje) {
        this.descuentoCambioPorcentaje = descuentoCambioPorcentaje;
    }

    public BigDecimal getCostoRetiro() {
        return costoRetiro;
    }

    public void setCostoRetiro(BigDecimal costoRetiro) {
        this.costoRetiro = costoRetiro;
    }

    public boolean isActivo() {
        return activo;
    }

    public void setActivo(boolean activo) {
        this.activo = activo;
    }

    public String getNotas() {
        return notas;
    }

    public void setNotas(String notas) {
        this.notas = notas;
    }
}
