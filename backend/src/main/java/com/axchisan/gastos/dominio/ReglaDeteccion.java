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
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.Locale;
import java.util.UUID;

/**
 * Qué hacer con los movimientos de una contraparte conocida: descartarlos (las transferencias
 * entre cuentas propias) o sugerir cómo registrarlos («este Nequi es de mamá: ingreso»).
 */
@Entity
@Table(name = "detection_rules")
public class ReglaDeteccion {

    public enum Campo { REFERENCIA, CONTRAPARTE }

    public enum Accion { DESCARTAR, SUGERIR }

    /** Cómo se registraría el movimiento al aceptarlo. */
    public enum Destino { GASTO, COMPRA, INGRESO, ABONO }

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private Usuario usuario;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Campo campo;

    @Column(nullable = false, length = 120)
    private String valor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Accion accion;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Destino destino;

    @Column(length = 30)
    private String categoria;

    @Column(length = 120)
    private String nombre;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected ReglaDeteccion() {
        // Requerido por JPA.
    }

    public ReglaDeteccion(Usuario usuario, Campo campo, String valor, Accion accion,
                          Destino destino, String categoria, String nombre) {
        if (valor == null || valor.isBlank()) {
            throw new IllegalArgumentException("La regla necesita un valor");
        }
        if (accion == Accion.SUGERIR && destino == null) {
            throw new IllegalArgumentException("Una regla que sugiere necesita un destino");
        }
        this.id = Identificadores.nuevo();
        this.usuario = usuario;
        this.campo = campo;
        this.valor = valor.trim();
        this.accion = accion;
        this.destino = destino;
        this.categoria = categoria;
        this.nombre = nombre;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
    }

    /**
     * Si la regla aplica: la referencia tiene que ser exactamente la misma (sin espacios); la
     * contraparte basta con que contenga el valor, sin distinguir mayúsculas, porque cada canal
     * la escribe distinto («MARIO PEREZ GOMEZ» en el PDF, «Mario Pérez Gómez» en el SMS).
     */
    public boolean aplica(String referencia, String contraparte) {
        if (campo == Campo.REFERENCIA) {
            return referencia != null
                    && sinEspacios(referencia).equals(sinEspacios(valor));
        }
        return contraparte != null && normalizar(contraparte).contains(normalizar(valor));
    }

    private static String sinEspacios(String s) {
        return s.replaceAll("[\\s*@]", "");
    }

    static String normalizar(String s) {
        return java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "").toLowerCase(Locale.ROOT).replaceAll("\\s+", " ").trim();
    }

    public UUID getId() {
        return id;
    }

    public Campo getCampo() {
        return campo;
    }

    public String getValor() {
        return valor;
    }

    public Accion getAccion() {
        return accion;
    }

    public Destino getDestino() {
        return destino;
    }

    public String getCategoria() {
        return categoria;
    }

    public String getNombre() {
        return nombre;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
