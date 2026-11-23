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
 * Un sitio donde hay dinero, con el saldo que tenía la última vez que se miró.
 *
 * <p>El saldo guardado es la cifra que mostraba el banco, o la que había en la billetera, cuando
 * se anotó. Lo que se apunta después (compras, pagos, ingresos) lo mueve: ese {@link #getCambio()
 * cambio} se calcula al leer, y {@link #getSaldoEstimado()} es lo que debería haber hoy.
 */
@Entity
@Table(name = "accounts")
public class Cuenta {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TipoCuenta tipo;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal saldo = BigDecimal.ZERO;

    @Column(name = "saldo_al", nullable = false)
    private LocalDate saldoAl;

    @Column(name = "saldo_anotado_en", nullable = false)
    private OffsetDateTime saldoAnotadoEn;

    /** Lo apuntado después de anotar el saldo; no se guarda, se calcula al leer. */
    @jakarta.persistence.Transient
    private BigDecimal cambio = BigDecimal.ZERO;

    @Column(nullable = false)
    private boolean activa = true;

    @Column(nullable = false)
    private short orden = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected Cuenta() {
        // Requerido por JPA.
    }

    public Cuenta(Usuario usuario, String nombre, TipoCuenta tipo) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.nombre = nombre;
        this.tipo = tipo;
        this.saldoAl = LocalDate.now();
    }

    @PrePersist
    void alCrear() {
        OffsetDateTime ahora = OffsetDateTime.now();
        this.createdAt = ahora;
        this.updatedAt = ahora;
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
        if (this.saldoAl == null) {
            this.saldoAl = LocalDate.now();
        }
        if (this.saldoAnotadoEn == null) {
            this.saldoAnotadoEn = ahora;
        }
    }

    @PreUpdate
    void alActualizar() {
        this.updatedAt = OffsetDateTime.now();
    }

    /**
     * Anota el saldo que se acaba de consultar.
     *
     * @param fecha día en que se miró; si falta, hoy
     */
    public void registrarSaldo(BigDecimal saldo, LocalDate fecha) {
        if (saldo == null) {
            throw new IllegalArgumentException("El saldo es obligatorio");
        }
        // Una cuenta de ahorros o el efectivo no bajan de cero; si algo da negativo es un
        // error al teclear, no un sobregiro.
        if (saldo.signum() < 0) {
            throw new IllegalArgumentException("El saldo de una cuenta no puede ser negativo");
        }
        this.saldo = saldo;
        this.saldoAl = fecha != null ? fecha : LocalDate.now();
        this.saldoAnotadoEn = OffsetDateTime.now();
        this.cambio = BigDecimal.ZERO;
    }

    public OffsetDateTime getSaldoAnotadoEn() {
        return saldoAnotadoEn;
    }

    public BigDecimal getCambio() {
        return cambio;
    }

    public void setCambio(BigDecimal cambio) {
        this.cambio = cambio == null ? BigDecimal.ZERO : cambio;
    }

    /** El saldo anotado más lo apuntado después: lo que debería haber hoy. */
    public BigDecimal getSaldoEstimado() {
        return saldo.add(cambio);
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

    public TipoCuenta getTipo() {
        return tipo;
    }

    public void setTipo(TipoCuenta tipo) {
        this.tipo = tipo;
    }

    public BigDecimal getSaldo() {
        return saldo;
    }

    public LocalDate getSaldoAl() {
        return saldoAl;
    }

    public boolean isActiva() {
        return activa;
    }

    public void setActiva(boolean activa) {
        this.activa = activa;
    }

    public short getOrden() {
        return orden;
    }

    public void setOrden(short orden) {
        this.orden = orden;
    }
}
