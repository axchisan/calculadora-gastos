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

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.util.UUID;

/** Una tarjeta con la que se paga: débito, o crédito con su ciclo de facturación. */
@Entity
@Table(name = "cards")
public class Tarjeta {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TipoTarjeta tipo;

    @Column(name = "dia_corte")
    private Short diaCorte;

    @Column(name = "dia_pago")
    private Short diaPago;

    @Column
    private String color;

    @Column(nullable = false)
    private boolean activa = true;

    @Column(nullable = false)
    private short orden = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected Tarjeta() {
        // Requerido por JPA.
    }

    public Tarjeta(Usuario usuario, String nombre, TipoTarjeta tipo) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.nombre = nombre;
        this.tipo = tipo;
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
     * Define el ciclo de facturación. Obligatorio en las de crédito.
     *
     * @throws IllegalArgumentException si los días no son válidos, o si se intenta poner un
     *                                  ciclo a una tarjeta de débito, que no lo tiene
     */
    public void definirCiclo(Integer diaCorte, Integer diaPago) {
        if (tipo != TipoTarjeta.CREDITO) {
            if (diaCorte != null || diaPago != null) {
                throw new IllegalArgumentException(
                        "Solo las tarjetas de crédito tienen día de corte y de pago");
            }
            this.diaCorte = null;
            this.diaPago = null;
            return;
        }
        if (diaCorte == null || diaPago == null) {
            throw new IllegalArgumentException(
                    "Una tarjeta de crédito necesita día de corte y día de pago");
        }
        // Se valida construyendo el ciclo, para no repetir aquí los mismos límites.
        CicloTarjeta ciclo = new CicloTarjeta(diaCorte, diaPago);
        this.diaCorte = (short) ciclo.diaCorte();
        this.diaPago = (short) ciclo.diaPago();
    }

    /**
     * El ciclo de facturación, o {@code null} si la tarjeta no lo tiene.
     *
     * <p>Las de débito nunca lo tienen: su dinero sale en el acto.
     */
    public CicloTarjeta ciclo() {
        if (diaCorte == null || diaPago == null) {
            return null;
        }
        return new CicloTarjeta(diaCorte, diaPago);
    }

    /**
     * Mes del que sale el dinero de una compra hecha con esta tarjeta en esa fecha.
     *
     * <p>Con débito es el mes de la propia compra. Con crédito lo decide el corte.
     */
    public YearMonth periodoDePago(LocalDate fechaCompra) {
        CicloTarjeta ciclo = ciclo();
        return ciclo == null ? YearMonth.from(fechaCompra) : ciclo.periodoDePago(fechaCompra);
    }

    public boolean esDeCredito() {
        return tipo == TipoTarjeta.CREDITO;
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

    public TipoTarjeta getTipo() {
        return tipo;
    }

    public Short getDiaCorte() {
        return diaCorte;
    }

    public Short getDiaPago() {
        return diaPago;
    }

    public String getColor() {
        return color;
    }

    public void setColor(String color) {
        this.color = color;
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
