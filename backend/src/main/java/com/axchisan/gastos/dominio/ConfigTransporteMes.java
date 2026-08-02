package com.axchisan.gastos.dominio;

import com.axchisan.gastos.transporte.ConfiguracionTransporte;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Parámetros del cálculo de transporte de un mes.
 *
 * <p>Se guardan por mes y no a nivel de usuario porque cualquiera de ellos puede cambiar: la
 * tarifa del pasaje sube, los días de karate se mueven, la política de trabajo remoto varía. Al
 * conservarlos junto al mes, el histórico sigue reflejando las condiciones reales de entonces.
 *
 * <p>Los días de la semana se almacenan como enteros ISO-8601 (1 = lunes … 7 = domingo).
 */
@Entity
@Table(name = "transport_configs")
public class ConfigTransporteMes {

    @Id
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "budget_month_id", nullable = false, unique = true)
    private MesPresupuestal mes;

    @Column(name = "valor_pasaje", nullable = false)
    private BigDecimal valorPasaje;

    @Column(name = "pasajes_dia_oficina", nullable = false)
    private short pasajesDiaOficina = 2;

    @Column(name = "pasajes_extra_karate", nullable = false)
    private short pasajesExtraKarate = 1;

    @Column(name = "pasajes_karate_desde_casa", nullable = false)
    private short pasajesKarateDesdeCasa = 2;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "dias_laborales", nullable = false)
    private Short[] diasLaborales = {1, 2, 3, 4, 5};

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "dias_karate", nullable = false)
    private Short[] diasKarate = {2, 4};

    @Column(name = "dias_remotos_por_semana", nullable = false)
    private short diasRemotosPorSemana = 1;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected ConfigTransporteMes() {
        // Requerido por JPA.
    }

    public ConfigTransporteMes(MesPresupuestal mes, BigDecimal valorPasaje) {
        this.id = Identificadores.nuevo();
        this.mes = mes;
        this.valorPasaje = valorPasaje;
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

    /** Traduce esta configuración al formato que consume el motor de cálculo. */
    public ConfiguracionTransporte aConfiguracionDeCalculo() {
        return new ConfiguracionTransporte(
                valorPasaje,
                pasajesDiaOficina,
                pasajesExtraKarate,
                pasajesKarateDesdeCasa,
                aDiasSemana(diasLaborales),
                aDiasSemana(diasKarate));
    }

    private static Set<DayOfWeek> aDiasSemana(Short[] valores) {
        if (valores == null || valores.length == 0) {
            return EnumSet.noneOf(DayOfWeek.class);
        }
        return Arrays.stream(valores)
                .map(v -> DayOfWeek.of(v))
                .collect(Collectors.toCollection(() -> EnumSet.noneOf(DayOfWeek.class)));
    }

    private static Short[] aEnteros(Set<DayOfWeek> dias) {
        return dias.stream()
                .map(d -> (short) d.getValue())
                .sorted()
                .toArray(Short[]::new);
    }

    public UUID getId() {
        return id;
    }

    public MesPresupuestal getMes() {
        return mes;
    }

    public BigDecimal getValorPasaje() {
        return valorPasaje;
    }

    public void setValorPasaje(BigDecimal valorPasaje) {
        this.valorPasaje = valorPasaje;
    }

    public short getPasajesDiaOficina() {
        return pasajesDiaOficina;
    }

    public void setPasajesDiaOficina(short pasajesDiaOficina) {
        this.pasajesDiaOficina = pasajesDiaOficina;
    }

    public short getPasajesExtraKarate() {
        return pasajesExtraKarate;
    }

    public void setPasajesExtraKarate(short pasajesExtraKarate) {
        this.pasajesExtraKarate = pasajesExtraKarate;
    }

    public short getPasajesKarateDesdeCasa() {
        return pasajesKarateDesdeCasa;
    }

    public void setPasajesKarateDesdeCasa(short pasajesKarateDesdeCasa) {
        this.pasajesKarateDesdeCasa = pasajesKarateDesdeCasa;
    }

    public Set<DayOfWeek> getDiasLaborales() {
        return aDiasSemana(diasLaborales);
    }

    public void setDiasLaborales(Set<DayOfWeek> dias) {
        this.diasLaborales = aEnteros(dias);
    }

    public Set<DayOfWeek> getDiasKarate() {
        return aDiasSemana(diasKarate);
    }

    public void setDiasKarate(Set<DayOfWeek> dias) {
        this.diasKarate = aEnteros(dias);
    }

    public short getDiasRemotosPorSemana() {
        return diasRemotosPorSemana;
    }

    public void setDiasRemotosPorSemana(short diasRemotosPorSemana) {
        this.diasRemotosPorSemana = diasRemotosPorSemana;
    }
}
