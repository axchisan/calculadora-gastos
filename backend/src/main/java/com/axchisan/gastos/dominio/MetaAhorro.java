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
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Destino al que se reparte el dinero disponible: fondo de emergencia, un viaje, una compra.
 *
 * <p>El {@link TipoAsignacion} define cómo reclama su parte del mes.
 */
@Entity
@Table(name = "savings_goals")
public class MetaAhorro {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_asignacion", nullable = false)
    private TipoAsignacion tipoAsignacion;

    /** Porcentaje o cantidad fija, según el tipo de asignación. */
    @Column(nullable = false)
    private BigDecimal valor;

    @Column(name = "meta_monto")
    private BigDecimal metaMonto;

    @Column(name = "saldo_acumulado", nullable = false)
    private BigDecimal saldoAcumulado = BigDecimal.ZERO;

    @Column
    private String color;

    @Column(nullable = false)
    private short prioridad = 0;

    @Column(nullable = false)
    private boolean activa = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected MetaAhorro() {
        // Requerido por JPA.
    }

    public MetaAhorro(Usuario usuario, String nombre, TipoAsignacion tipoAsignacion,
                      BigDecimal valor) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.nombre = nombre;
        this.tipoAsignacion = tipoAsignacion;
        this.valor = valor;
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
     * Calcula cuánto reclama esta meta.
     *
     * @param ingresoTotal ingreso del mes, base de los porcentajes sobre ingreso
     * @param sobrante     dinero libre tras gastos y deudas, base de los porcentajes sobre sobrante
     */
    public BigDecimal calcularAporte(BigDecimal ingresoTotal, BigDecimal sobrante) {
        BigDecimal aporte = switch (tipoAsignacion) {
            case MONTO_FIJO -> valor;
            case PORCENTAJE_INGRESO -> porcentajeDe(ingresoTotal);
            case PORCENTAJE_SOBRANTE -> porcentajeDe(sobrante);
        };
        // No se reparte dinero que no existe: si el sobrante es negativo, el aporte es cero.
        if (aporte.signum() < 0) {
            return BigDecimal.ZERO;
        }
        // Tampoco tiene sentido superar el objetivo cuando ya está definido.
        if (metaMonto != null) {
            BigDecimal restante = metaMonto.subtract(saldoAcumulado);
            return restante.signum() <= 0 ? BigDecimal.ZERO : aporte.min(restante);
        }
        return aporte;
    }

    private BigDecimal porcentajeDe(BigDecimal base) {
        if (base == null || base.signum() <= 0) {
            return BigDecimal.ZERO;
        }
        return base.multiply(valor).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
    }

    /** Porcentaje del objetivo ya alcanzado, o vacío si la meta no tiene objetivo definido. */
    public BigDecimal porcentajeAlcanzado() {
        if (metaMonto == null || metaMonto.signum() == 0) {
            return null;
        }
        return saldoAcumulado.multiply(BigDecimal.valueOf(100))
                .divide(metaMonto, 2, RoundingMode.HALF_UP)
                .min(BigDecimal.valueOf(100));
    }

    public void aplicarMovimiento(TipoMovimientoAhorro tipo, BigDecimal monto) {
        this.saldoAcumulado = tipo == TipoMovimientoAhorro.APORTE
                ? saldoAcumulado.add(monto)
                : saldoAcumulado.subtract(monto);
        if (this.saldoAcumulado.signum() < 0) {
            throw new IllegalArgumentException(
                    "El retiro deja la meta en negativo; el saldo disponible es "
                            + saldoAcumulado.add(monto));
        }
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

    public TipoAsignacion getTipoAsignacion() {
        return tipoAsignacion;
    }

    public void setTipoAsignacion(TipoAsignacion tipoAsignacion) {
        this.tipoAsignacion = tipoAsignacion;
    }

    public BigDecimal getValor() {
        return valor;
    }

    public void setValor(BigDecimal valor) {
        this.valor = valor;
    }

    public BigDecimal getMetaMonto() {
        return metaMonto;
    }

    public void setMetaMonto(BigDecimal metaMonto) {
        this.metaMonto = metaMonto;
    }

    public BigDecimal getSaldoAcumulado() {
        return saldoAcumulado;
    }

    public String getColor() {
        return color;
    }

    public void setColor(String color) {
        this.color = color;
    }

    public short getPrioridad() {
        return prioridad;
    }

    public void setPrioridad(short prioridad) {
        this.prioridad = prioridad;
    }

    public boolean isActiva() {
        return activa;
    }

    public void setActiva(boolean activa) {
        this.activa = activa;
    }
}
