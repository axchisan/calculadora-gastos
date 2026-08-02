package com.axchisan.gastos.dominio;

import com.axchisan.gastos.transporte.DiaTransporte;
import com.axchisan.gastos.transporte.TipoDia;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.LocalDate;
import java.util.UUID;

/** Un día del mes con su clasificación y los pasajes que le corresponden. */
@Entity
@Table(name = "transport_days")
public class DiaTransporteMes {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "budget_month_id", nullable = false)
    private MesPresupuestal mes;

    @Column(nullable = false)
    private LocalDate fecha;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TipoDia tipo;

    @Column(name = "hay_karate", nullable = false)
    private boolean hayKarate = false;

    @Column(nullable = false)
    private short pasajes = 0;

    @Column(name = "override_manual", nullable = false)
    private boolean overrideManual = false;

    @Column(nullable = false)
    private boolean confirmado = false;

    @Column(name = "nombre_festivo")
    private String nombreFestivo;

    @Column
    private String nota;

    protected DiaTransporteMes() {
        // Requerido por JPA.
    }

    public DiaTransporteMes(MesPresupuestal mes, DiaTransporte dia) {
        this.id = Identificadores.nuevo();
        this.mes = mes;
        aplicar(dia);
    }

    @PrePersist
    void alCrear() {
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    /** Vuelca sobre esta fila el resultado del motor de cálculo. */
    public void aplicar(DiaTransporte dia) {
        this.fecha = dia.fecha();
        this.tipo = dia.tipo();
        this.hayKarate = dia.hayKarate();
        this.pasajes = (short) dia.pasajes();
        this.overrideManual = dia.overrideManual();
        this.confirmado = dia.confirmado();
        this.nombreFestivo = dia.nombreFestivo();
    }

    /** Traduce esta fila al formato que consume el motor de cálculo. */
    public DiaTransporte aDiaDeCalculo() {
        return new DiaTransporte(fecha, tipo, hayKarate, pasajes, overrideManual, confirmado,
                nombreFestivo);
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

    public TipoDia getTipo() {
        return tipo;
    }

    public void setTipo(TipoDia tipo) {
        this.tipo = tipo;
        // Reclasificar el día invalida cualquier ajuste manual previo de pasajes.
        this.overrideManual = false;
    }

    public boolean isHayKarate() {
        return hayKarate;
    }

    public void setHayKarate(boolean hayKarate) {
        this.hayKarate = hayKarate;
    }

    public short getPasajes() {
        return pasajes;
    }

    /** Fija los pasajes a mano, protegiéndolos de los recálculos automáticos. */
    public void fijarPasajesManualmente(short pasajes) {
        this.pasajes = pasajes;
        this.overrideManual = true;
    }

    public boolean isOverrideManual() {
        return overrideManual;
    }

    public boolean isConfirmado() {
        return confirmado;
    }

    public void setConfirmado(boolean confirmado) {
        this.confirmado = confirmado;
    }

    public String getNombreFestivo() {
        return nombreFestivo;
    }

    public String getNota() {
        return nota;
    }

    public void setNota(String nota) {
        this.nota = nota;
    }
}
