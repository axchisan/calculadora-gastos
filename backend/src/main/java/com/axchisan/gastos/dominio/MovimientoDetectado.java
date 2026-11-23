package com.axchisan.gastos.dominio;

import com.axchisan.gastos.deteccion.AvisoBancario;
import com.axchisan.gastos.deteccion.ClaseMovimiento;
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

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Un movimiento que llegó de fuera (correo, SMS, extracto) y espera en la bandeja «Por revisar».
 */
@Entity
@Table(name = "detected_movements")
public class MovimientoDetectado {

    public enum Origen { CORREO, SMS, PDF, NOTIFICACION }

    public enum Estado {
        /** Espera a que el usuario decida. */
        PENDIENTE,
        ACEPTADO,
        DESCARTADO,
        /** Coincide con algo que ya estaba apuntado en la app. */
        YA_REGISTRADO,
        /** El mismo movimiento ya llegó por otro canal. */
        DUPLICADO,
        /** No encajó en ninguna plantilla: se guarda para revisar la plantilla. */
        NO_RECONOCIDO
    }

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Origen origen;

    @Column(nullable = false, length = 20)
    private String banco;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private ClaseMovimiento clase;

    @Column(precision = 14, scale = 2)
    private BigDecimal monto;

    @Column
    private Boolean entra;

    @Column
    private LocalDate fecha;

    @Column
    private LocalTime hora;

    @Column(length = 20)
    private String cuenta;

    @Column(length = 200)
    private String contraparte;

    @Column(length = 100)
    private String referencia;

    @Column(nullable = false)
    private String texto;

    @Column(nullable = false, length = 64)
    private String huella;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Estado estado;

    @Column(length = 200)
    private String motivo;

    @Column(name = "duplicado_de")
    private UUID duplicadoDe;

    @Column(name = "coincide_tipo", length = 10)
    private String coincideTipo;

    @Column(name = "coincide_id")
    private UUID coincideId;

    @Column(name = "regla_id")
    private UUID reglaId;

    @Enumerated(EnumType.STRING)
    @Column(name = "sugerencia_destino", length = 10)
    private ReglaDeteccion.Destino sugerenciaDestino;

    @Column(name = "sugerencia_categoria", length = 30)
    private String sugerenciaCategoria;

    @Column(name = "sugerencia_nombre", length = 120)
    private String sugerenciaNombre;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "resuelto_at")
    private OffsetDateTime resueltoAt;

    protected MovimientoDetectado() {
        // Requerido por JPA.
    }

    /** Un aviso o una línea que sí se entendió: queda pendiente. */
    public MovimientoDetectado(Usuario usuario, Origen origen, AvisoBancario aviso, String texto,
                               String huella) {
        this(usuario, origen, aviso.banco(), texto, huella, Estado.PENDIENTE);
        this.clase = aviso.clase();
        this.monto = aviso.monto();
        this.entra = aviso.entra();
        this.fecha = aviso.fecha();
        this.hora = aviso.hora();
        this.cuenta = aviso.cuenta();
        this.contraparte = recortar(aviso.contraparte(), 200);
        this.referencia = recortar(aviso.referencia(), 100);
    }

    /** Un aviso que no encajó en ninguna plantilla. */
    public static MovimientoDetectado noReconocido(Usuario usuario, Origen origen, String banco,
                                                   String texto, String huella) {
        return new MovimientoDetectado(usuario, origen, banco, texto, huella,
                Estado.NO_RECONOCIDO);
    }

    private MovimientoDetectado(Usuario usuario, Origen origen, String banco, String texto,
                                String huella, Estado estado) {
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.origen = origen;
        this.banco = banco;
        this.texto = texto;
        this.huella = huella;
        this.estado = estado;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
    }

    private static String recortar(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max);
    }

    /** El monto con signo: positivo si entra, negativo si sale. */
    public BigDecimal montoConSigno() {
        if (monto == null) {
            return null;
        }
        return Boolean.TRUE.equals(entra) ? monto : monto.negate();
    }

    public void marcarDuplicado(MovimientoDetectado original) {
        this.estado = Estado.DUPLICADO;
        this.duplicadoDe = original.getId();
        this.motivo = "Ya llegó por " + original.getOrigen().name().toLowerCase();
        this.resueltoAt = OffsetDateTime.now();
    }

    public void marcarYaRegistrado(String tipo, UUID id, String descripcion) {
        this.estado = Estado.YA_REGISTRADO;
        this.coincideTipo = tipo;
        this.coincideId = id;
        this.motivo = recortar(descripcion, 200);
        this.resueltoAt = OffsetDateTime.now();
    }

    public void descartar(String motivo) {
        this.estado = Estado.DESCARTADO;
        this.motivo = recortar(motivo, 200);
        this.resueltoAt = OffsetDateTime.now();
    }

    public void aplicarRegla(ReglaDeteccion regla) {
        this.reglaId = regla.getId();
        if (regla.getAccion() == ReglaDeteccion.Accion.DESCARTAR) {
            descartar(regla.getNombre() != null ? regla.getNombre() : "Regla: se descarta");
        } else {
            sugerir(regla.getDestino(), regla.getCategoria(), regla.getNombre());
        }
    }

    public void sugerir(ReglaDeteccion.Destino destino, String categoria, String nombre) {
        this.sugerenciaDestino = destino;
        this.sugerenciaCategoria = categoria;
        this.sugerenciaNombre = recortar(nombre, 120);
    }

    /** Vuelve a la bandeja algo que se había descartado o marcado. */
    public void reabrir() {
        if (estado == Estado.NO_RECONOCIDO) {
            throw new IllegalStateException("Un aviso no reconocido no se puede reabrir");
        }
        this.estado = Estado.PENDIENTE;
        this.motivo = null;
        this.duplicadoDe = null;
        this.coincideTipo = null;
        this.coincideId = null;
        this.resueltoAt = null;
    }

    public UUID getId() {
        return id;
    }

    public Origen getOrigen() {
        return origen;
    }

    public String getBanco() {
        return banco;
    }

    public ClaseMovimiento getClase() {
        return clase;
    }

    public BigDecimal getMonto() {
        return monto;
    }

    public Boolean getEntra() {
        return entra;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public LocalTime getHora() {
        return hora;
    }

    public String getCuenta() {
        return cuenta;
    }

    public String getContraparte() {
        return contraparte;
    }

    public String getReferencia() {
        return referencia;
    }

    public String getTexto() {
        return texto;
    }

    public String getHuella() {
        return huella;
    }

    public Estado getEstado() {
        return estado;
    }

    public String getMotivo() {
        return motivo;
    }

    public UUID getDuplicadoDe() {
        return duplicadoDe;
    }

    public String getCoincideTipo() {
        return coincideTipo;
    }

    public UUID getCoincideId() {
        return coincideId;
    }

    public UUID getReglaId() {
        return reglaId;
    }

    public ReglaDeteccion.Destino getSugerenciaDestino() {
        return sugerenciaDestino;
    }

    public String getSugerenciaCategoria() {
        return sugerenciaCategoria;
    }

    public String getSugerenciaNombre() {
        return sugerenciaNombre;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getResueltoAt() {
        return resueltoAt;
    }
}
