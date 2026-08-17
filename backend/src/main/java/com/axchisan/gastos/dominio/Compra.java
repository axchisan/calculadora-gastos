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
import java.time.YearMonth;
import java.util.UUID;

/**
 * Una compra del día a día: el agua, el chocorramo, la comisión del cajero.
 *
 * <p>Se separa de {@link Gasto} porque su ciclo de vida es distinto. Un gasto es un compromiso
 * que se contrae y luego se paga, y por eso tiene estado y admite abonos parciales. Una compra
 * ya ocurrió: no hay nada pendiente que decidir sobre ella. Lo único que varía es de dónde
 * salió el dinero y, si fue de una tarjeta de crédito, cuándo saldrá de verdad.
 */
@Entity
@Table(name = "purchases")
public class Compra {

    @Id
    private UUID id;

    /** Mes en que se hizo la compra. Con crédito no es el mes del que sale el dinero. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "budget_month_id", nullable = false)
    private MesPresupuestal mes;

    @Column(nullable = false)
    private LocalDate fecha;

    @Column(nullable = false)
    private String descripcion;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CategoriaGasto categoria;

    @Column(nullable = false)
    private BigDecimal monto;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private MedioPago medio = MedioPago.EFECTIVO;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "card_id")
    private Tarjeta tarjeta;

    @Column(name = "pago_anio", nullable = false)
    private short pagoAnio;

    @Column(name = "pago_mes", nullable = false)
    private short pagoMes;

    @Column(nullable = false)
    private boolean pagado = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrigenCompra origen = OrigenCompra.MANUAL;

    @Column
    private String nota;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected Compra() {
        // Requerido por JPA.
    }

    public Compra(MesPresupuestal mes, LocalDate fecha, String descripcion,
                  CategoriaGasto categoria, BigDecimal monto) {
        this.id = Identificadores.nuevo();
        this.mes = mes;
        this.fecha = fecha;
        this.descripcion = descripcion;
        this.categoria = categoria;
        this.monto = monto;
        aplicarMedio(MedioPago.EFECTIVO, null);
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
     * Fija con qué se pagó y, de ahí, de qué mes sale el dinero.
     *
     * <p>Con efectivo o débito el dinero ya salió: el periodo de pago es el de la compra y
     * queda saldada. Con crédito el periodo lo decide el corte de la tarjeta y la compra nace
     * pendiente, porque el dinero no ha salido todavía.
     *
     * @throws IllegalArgumentException si el medio y la tarjeta no encajan
     */
    public void aplicarMedio(MedioPago medio, Tarjeta tarjeta) {
        if (medio == MedioPago.CREDITO) {
            if (tarjeta == null || !tarjeta.esDeCredito()) {
                throw new IllegalArgumentException(
                        "Una compra a crédito necesita una tarjeta de crédito");
            }
        } else if (tarjeta != null && tarjeta.esDeCredito()) {
            throw new IllegalArgumentException(
                    "La tarjeta " + tarjeta.getNombre() + " es de crédito; "
                            + "el medio de pago debe serlo también");
        }

        this.medio = medio;
        this.tarjeta = tarjeta;

        YearMonth periodo = medio == MedioPago.CREDITO
                ? tarjeta.periodoDePago(fecha)
                : YearMonth.from(fecha);
        this.pagoAnio = (short) periodo.getYear();
        this.pagoMes = (short) periodo.getMonthValue();

        // Lo que se paga en el acto nace saldado; el crédito, no.
        this.pagado = medio.saleAlInstante();
    }

    /**
     * Cambia la fecha de la compra, recalculando de qué mes sale el dinero.
     *
     * <p>Con crédito, mover la compra dos días puede desplazar el pago un mes entero.
     */
    public void cambiarFecha(LocalDate nueva) {
        this.fecha = nueva;
        aplicarMedio(this.medio, this.tarjeta);
    }

    /** Mes del que sale el dinero. */
    public YearMonth periodoDePago() {
        return YearMonth.of(pagoAnio, pagoMes);
    }

    /** Marca el corte como pagado o lo devuelve a pendiente. */
    public void marcarPagado(boolean pagado) {
        if (medio.saleAlInstante() && !pagado) {
            throw new IllegalArgumentException(
                    "Una compra en efectivo o débito ya salió del bolsillo; "
                            + "no puede quedar pendiente");
        }
        this.pagado = pagado;
    }

    /** Fecha en que vence el pago, o la de la compra si el dinero ya salió. */
    public LocalDate vencimiento() {
        if (medio.saleAlInstante() || tarjeta == null || tarjeta.ciclo() == null) {
            return fecha;
        }
        return tarjeta.ciclo().vencimientoDe(fecha);
    }

    public UUID getId() {
        return id;
    }

    public MesPresupuestal getMes() {
        return mes;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
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

    public void setMonto(BigDecimal monto) {
        if (monto == null || monto.signum() <= 0) {
            throw new IllegalArgumentException("El monto de una compra debe ser mayor que cero");
        }
        this.monto = monto;
    }

    public MedioPago getMedio() {
        return medio;
    }

    public Tarjeta getTarjeta() {
        return tarjeta;
    }

    public boolean isPagado() {
        return pagado;
    }

    public OrigenCompra getOrigen() {
        return origen;
    }

    public void setOrigen(OrigenCompra origen) {
        this.origen = origen;
    }

    public String getNota() {
        return nota;
    }

    public void setNota(String nota) {
        this.nota = nota;
    }
}
