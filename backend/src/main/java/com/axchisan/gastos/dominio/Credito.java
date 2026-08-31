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
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Un crédito bancario con su cuadro de amortización.
 *
 * <p>Se distingue de una {@link Deuda} en que no es una cifra que se va abonando a ojo, sino un
 * plan cerrado: cada cuota tiene fecha y un reparto entre capital e interés. Ese reparto es lo
 * que permite responder a la única pregunta que de verdad importa aquí, que es cuánto se ahorra
 * si se abona de más.
 */
@Entity
@Table(name = "credits")
public class Credito {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private String entidad;

    @Column(name = "numero_operacion")
    private String numeroOperacion;

    @Column
    private String descripcion;

    @Column(name = "monto_original", nullable = false)
    private BigDecimal montoOriginal;

    /** Tasa efectiva anual en porcentaje, tal y como la publica el banco. */
    @Column(name = "tasa_ea")
    private BigDecimal tasaEa;

    @Column(name = "plazo_cuotas", nullable = false)
    private short plazoCuotas;

    @Column(name = "dia_pago")
    private Short diaPago;

    @Column(name = "fecha_desembolso")
    private LocalDate fechaDesembolso;

    @Column(name = "fecha_vencimiento")
    private LocalDate fechaVencimiento;

    @Column(nullable = false)
    private boolean activo = true;

    @OneToMany(mappedBy = "credito", cascade = CascadeType.ALL, orphanRemoval = true,
            fetch = FetchType.LAZY)
    @OrderBy("numero")
    private List<CuotaCredito> cuotas = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected Credito() {
        // Requerido por JPA.
    }

    public Credito(Usuario usuario, String entidad, BigDecimal montoOriginal, int plazoCuotas) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.entidad = entidad;
        this.montoOriginal = montoOriginal;
        this.plazoCuotas = (short) plazoCuotas;
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

    public void anadirCuota(CuotaCredito cuota) {
        cuota.asignarCredito(this);
        this.cuotas.add(cuota);
    }

    /**
     * La tasa mensual equivalente a la efectiva anual.
     *
     * <p>Devuelve cero si el crédito no la tiene registrada, lo que deja las simulaciones en un
     * simple reparto del saldo en lugar de inventarse un interés.
     */
    public double tasaMensual() {
        if (tasaEa == null || tasaEa.signum() <= 0) {
            return 0;
        }
        return com.axchisan.gastos.credito.Amortizacion
                .mensualDesdeEfectivaAnual(tasaEa.doubleValue());
    }

    public UUID getId() {
        return id;
    }

    public Usuario getUsuario() {
        return usuario;
    }

    public String getEntidad() {
        return entidad;
    }

    public void setEntidad(String entidad) {
        this.entidad = entidad;
    }

    public String getNumeroOperacion() {
        return numeroOperacion;
    }

    public void setNumeroOperacion(String numeroOperacion) {
        this.numeroOperacion = numeroOperacion;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public BigDecimal getMontoOriginal() {
        return montoOriginal;
    }

    public BigDecimal getTasaEa() {
        return tasaEa;
    }

    public void setTasaEa(BigDecimal tasaEa) {
        this.tasaEa = tasaEa;
    }

    public short getPlazoCuotas() {
        return plazoCuotas;
    }

    public Short getDiaPago() {
        return diaPago;
    }

    public void setDiaPago(Short diaPago) {
        this.diaPago = diaPago;
    }

    public LocalDate getFechaDesembolso() {
        return fechaDesembolso;
    }

    public void setFechaDesembolso(LocalDate fechaDesembolso) {
        this.fechaDesembolso = fechaDesembolso;
    }

    public LocalDate getFechaVencimiento() {
        return fechaVencimiento;
    }

    public void setFechaVencimiento(LocalDate fechaVencimiento) {
        this.fechaVencimiento = fechaVencimiento;
    }

    public boolean isActivo() {
        return activo;
    }

    public void setActivo(boolean activo) {
        this.activo = activo;
    }

    public List<CuotaCredito> getCuotas() {
        return cuotas;
    }
}
