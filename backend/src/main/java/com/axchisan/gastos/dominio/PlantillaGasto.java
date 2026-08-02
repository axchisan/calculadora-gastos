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
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Gasto fijo que se repite cada mes.
 *
 * <p>Al crear un mes nuevo, cada plantilla activa genera un {@link Gasto}. Modificar la plantilla
 * después <b>no</b> altera los meses ya creados: así, subir el arriendo en septiembre no reescribe
 * lo que realmente se pagó en agosto.
 */
@Entity
@Table(name = "expense_templates")
public class PlantillaGasto {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Column(nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CategoriaGasto categoria;

    @Column(name = "monto_default", nullable = false)
    private BigDecimal montoDefault = BigDecimal.ZERO;

    @Column(name = "dia_vencimiento")
    private Short diaVencimiento;

    @Column(nullable = false)
    private boolean activo = true;

    @Column(nullable = false)
    private short orden = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected PlantillaGasto() {
        // Requerido por JPA.
    }

    public PlantillaGasto(Usuario usuario, String nombre, CategoriaGasto categoria,
                          BigDecimal montoDefault) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.nombre = nombre;
        this.categoria = categoria;
        this.montoDefault = montoDefault == null ? BigDecimal.ZERO : montoDefault;
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

    /** Crea el gasto correspondiente a esta plantilla para un mes. */
    public Gasto generarGasto() {
        Gasto gasto = new Gasto(nombre, categoria, montoDefault, OrigenGasto.PLANTILLA);
        gasto.setPlantillaId(id);
        gasto.setDiaVencimiento(diaVencimiento);
        gasto.setOrden(orden);
        return gasto;
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

    public CategoriaGasto getCategoria() {
        return categoria;
    }

    public void setCategoria(CategoriaGasto categoria) {
        this.categoria = categoria;
    }

    public BigDecimal getMontoDefault() {
        return montoDefault;
    }

    public void setMontoDefault(BigDecimal montoDefault) {
        this.montoDefault = montoDefault;
    }

    public Short getDiaVencimiento() {
        return diaVencimiento;
    }

    public void setDiaVencimiento(Short diaVencimiento) {
        this.diaVencimiento = diaVencimiento;
    }

    public boolean isActivo() {
        return activo;
    }

    public void setActivo(boolean activo) {
        this.activo = activo;
    }

    public short getOrden() {
        return orden;
    }

    public void setOrden(short orden) {
        this.orden = orden;
    }
}
