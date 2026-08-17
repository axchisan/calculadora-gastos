package com.axchisan.gastos.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.text.Normalizer;
import java.time.OffsetDateTime;
import java.util.Locale;
import java.util.UUID;

/**
 * Cómo se reconoce una tarjeta en las notificaciones de pago del teléfono.
 *
 * <p>Google Wallet publica el apodo que el usuario le puso a la tarjeta dentro de la billetera
 * («crédito física»); el banco publica los cuatro últimos dígitos («terminada en 2355»). Ninguno
 * es el nombre que la tarjeta tiene aquí, y de esa traducción depende algo que no es menor: si
 * la compra salió del dinero de hoy o se va al corte del mes que viene.
 */
@Entity
@Table(name = "card_aliases")
public class AliasTarjeta {

    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "card_id", nullable = false)
    private Tarjeta tarjeta;

    @Column
    private String alias;

    @Column(name = "alias_norm")
    private String aliasNorm;

    @Column(name = "ultimos4")
    private String ultimos4;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected AliasTarjeta() {
        // Requerido por JPA.
    }

    public AliasTarjeta(Tarjeta tarjeta, String alias, String ultimos4) {
        if ((alias == null || alias.isBlank()) && (ultimos4 == null || ultimos4.isBlank())) {
            throw new IllegalArgumentException(
                    "Hay que indicar el apodo de la tarjeta en la billetera, "
                            + "sus cuatro últimos dígitos, o ambos");
        }
        if (ultimos4 != null && !ultimos4.isBlank() && !ultimos4.matches("\\d{4}")) {
            throw new IllegalArgumentException("Los últimos dígitos deben ser exactamente cuatro");
        }

        this.id = Identificadores.nuevo();
        this.tarjeta = tarjeta;
        this.alias = alias == null || alias.isBlank() ? null : alias.trim();
        this.aliasNorm = normalizar(this.alias);
        this.ultimos4 = ultimos4 == null || ultimos4.isBlank() ? null : ultimos4;
    }

    @PrePersist
    void alCrear() {
        this.createdAt = OffsetDateTime.now();
        if (this.id == null) {
            this.id = Identificadores.nuevo();
        }
    }

    /**
     * Deja un texto comparable: minúsculas y sin tildes.
     *
     * <p>Hace falta porque el propio usuario escribió «crédito física» con tilde y «credito
     * digital» sin ella. Comparando el texto crudo, uno de los dos no se reconocería nunca.
     */
    public static String normalizar(String texto) {
        if (texto == null) {
            return null;
        }
        // La forma NFD separa cada letra de su tilde, que queda como carácter aparte y se puede
        // borrar por rango; sin esa descomposición, 'é' es un único carácter indivisible.
        String sinTildes = Normalizer.normalize(texto, Normalizer.Form.NFD)
                .replaceAll("\\p{InCombiningDiacriticalMarks}+", "");
        return sinTildes.toLowerCase(Locale.ROOT).trim();
    }

    public UUID getId() {
        return id;
    }

    public Tarjeta getTarjeta() {
        return tarjeta;
    }

    public String getAlias() {
        return alias;
    }

    public String getAliasNorm() {
        return aliasNorm;
    }

    public String getUltimos4() {
        return ultimos4;
    }
}
