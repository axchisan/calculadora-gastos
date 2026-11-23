package com.axchisan.gastos.deteccion;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Lee los avisos de movimientos de Bancolombia. El correo de «Alertas y Notificaciones» y el SMS
 * dicen lo mismo con el mismo texto («Bancolombia: Compraste $X en …»), así que sirve para los dos.
 *
 * <p>Las plantillas salen de los avisos reales de 2026. Bancolombia no es consistente ni dentro de
 * una misma plantilla: el importe llega como {@code $40,000}, {@code $2.000,00} o
 * {@code $150000.00}; la fecha como {@code dd/mm/aaaa}, {@code dd/mm/aa} o {@code aaaa/mm/dd}; la
 * cuenta con o sin asterisco; y en una plantilla la hora va antes que la fecha. Por eso el monto,
 * la fecha y la hora se interpretan aparte, de forma tolerante, y cada plantilla solo se ocupa de
 * reconocer el tipo de movimiento y sus partes.
 */
public final class LectorAvisosBancolombia {

    public static final String BANCO = "BANCOLOMBIA";

    private static final String MONTO = "\\$\\s?(?<monto>[\\d.,]+)";
    private static final String CUENTA = "\\*{0,2}(?<cuenta>\\d{3,})";

    private record Plantilla(ClaseMovimiento clase, Pattern patron) {
    }

    // El orden importa: las más específicas antes que las generales.
    private static final List<Plantilla> PLANTILLAS = List.of(
            plantilla(ClaseMovimiento.COMPRA,
                    "Compraste " + MONTO + " en (?<contra>.+?)\\s*con tu T\\.\\s?(?:Deb|Cred|Cr[eé]d)\\w*\\s+"
                            + CUENTA),
            plantilla(ClaseMovimiento.RETIRO,
                    "Retiraste " + MONTO + " en (?<contra>.+?) de tu T\\.\\s?Deb\\w*\\s+" + CUENTA),
            plantilla(ClaseMovimiento.PAGO_QR,
                    "pagaste " + MONTO + " por c[oó]digo QR desde tu cuenta " + CUENTA
                            + " a la llave (?<ref>\\S+)"),
            plantilla(ClaseMovimiento.PAGO_QR,
                    "Transferiste " + MONTO + " por QR desde tu cuenta " + CUENTA
                            + " a la cuenta \\*? ?(?<ref>\\d+)"),
            plantilla(ClaseMovimiento.TRANSFERENCIA_ENVIADA,
                    "Transferiste " + MONTO + " por Bot[oó]n Bancolombia a (?<contra>.+?) desde producto "
                            + CUENTA),
            plantilla(ClaseMovimiento.TRANSFERENCIA_ENVIADA,
                    "transferiste " + MONTO + " a la llave (?<ref>\\S+) desde tu cuenta " + CUENTA
                            + " a (?<contra>.+?)\\s*el \\d"),
            plantilla(ClaseMovimiento.TRANSFERENCIA_ENVIADA,
                    "Transferiste " + MONTO + " desde tu cuenta " + CUENTA
                            + " a la cuenta \\*? ?(?<ref>\\d+)"),
            plantilla(ClaseMovimiento.NOMINA,
                    "Recibiste un pago de N[oó]mina de (?<contra>.+?) por " + MONTO),
            plantilla(ClaseMovimiento.TRANSFERENCIA_RECIBIDA,
                    "Recibiste un pago (?!por )\\p{L}+ de (?<contra>.+?) por " + MONTO),
            plantilla(ClaseMovimiento.TRANSFERENCIA_RECIBIDA,
                    "Recibiste una consignaci[oó]n por " + MONTO
                            + " desde (?:el )?(?<contra>corresponsal|cajero|oficina)"),
            plantilla(ClaseMovimiento.TRANSFERENCIA_RECIBIDA,
                    "recibiste una transferencia de (?<contra>.+?)\\s*por " + MONTO
                            + " en tu cuenta " + CUENTA
                            + "(?: conectada a la llave (?<ref>\\S+))?"),
            plantilla(ClaseMovimiento.TRANSFERENCIA_RECIBIDA,
                    "Recibiste un pago por " + MONTO + " de (?<contra>.+?)\\s*a tu cuenta"),
            plantilla(ClaseMovimiento.PAGO,
                    "Pagaste " + MONTO + " a (?<contra>.+?)\\s*desde tu producto " + CUENTA));

    /** Avisos del banco que no son movimientos: rechazos, códigos, recordatorios. */
    private static final Pattern NO_ES_MOVIMIENTO = Pattern.compile(
            "rechazad|es el c[oó]digo|es tu c[oó]digo|Autorizaste a|Te identificaste"
                    + "|Muy pronto cobraremos|no te alcanz|suman tus gastos|Recibir[aá]s \\$"
                    + "|tienda online",
            Pattern.CASE_INSENSITIVE);

    private static final Pattern FECHA_DMA =
            Pattern.compile("(?<!\\d)(\\d{1,2})/(\\d{1,2})/(\\d{4}|\\d{2})(?!\\d)");
    private static final Pattern FECHA_AMD =
            Pattern.compile("(?<!\\d)(\\d{4})/(\\d{1,2})/(\\d{1,2})(?!\\d)");
    private static final Pattern HORA =
            Pattern.compile("(?<![\\d/])(\\d{1,2}):(\\d{2})(?::(\\d{2}))?(?![\\d/])");

    private LectorAvisosBancolombia() {
    }

    private static Plantilla plantilla(ClaseMovimiento clase, String regex) {
        return new Plantilla(clase, Pattern.compile(regex, Pattern.CASE_INSENSITIVE));
    }

    /** Si es un aviso del banco que no cuenta un movimiento (un código, un pago rechazado…). */
    public static boolean noEsMovimiento(String texto) {
        // Sin un importe no hay movimiento: activar la tarjeta, inscribir una llave, cambiar
        // los datos de contacto…
        return texto == null || !texto.contains("$") || NO_ES_MOVIMIENTO.matcher(texto).find();
    }

    /**
     * Interpreta un aviso. Vacío si no es un movimiento de Bancolombia o no encaja en ninguna
     * plantilla conocida (en ese caso conviene guardarlo para revisarlo: puede ser una plantilla
     * nueva).
     */
    public static Optional<AvisoBancario> leer(String texto) {
        if (texto == null || texto.isBlank()) {
            return Optional.empty();
        }
        String limpio = texto.replaceAll("\\s+", " ").trim();
        if (NO_ES_MOVIMIENTO.matcher(limpio).find()) {
            return Optional.empty();
        }
        for (Plantilla p : PLANTILLAS) {
            Matcher m = p.patron().matcher(limpio);
            if (!m.find()) {
                continue;
            }
            BigDecimal monto = Importes.interpretar(m.group("monto"));
            // La fecha y la hora se buscan después del importe: antes puede haber números del
            // remitente o del comercio que se parezcan.
            String resto = limpio.substring(m.start());
            LocalDate fecha = fecha(resto);
            if (monto == null || fecha == null) {
                return Optional.empty();
            }
            return Optional.of(new AvisoBancario(BANCO, p.clase(), monto, fecha, hora(resto),
                    grupo(m, "cuenta"), limpiar(grupo(m, "contra")), grupo(m, "ref")));
        }
        return Optional.empty();
    }

    static LocalDate fecha(String texto) {
        Matcher amd = FECHA_AMD.matcher(texto);
        if (amd.find()) {
            return crear(Integer.parseInt(amd.group(1)), Integer.parseInt(amd.group(2)),
                    Integer.parseInt(amd.group(3)));
        }
        Matcher dma = FECHA_DMA.matcher(texto);
        if (dma.find()) {
            int anio = Integer.parseInt(dma.group(3));
            if (anio < 100) {
                anio += 2000;
            }
            return crear(anio, Integer.parseInt(dma.group(2)), Integer.parseInt(dma.group(1)));
        }
        return null;
    }

    private static LocalDate crear(int anio, int mes, int dia) {
        try {
            return LocalDate.of(anio, mes, dia);
        } catch (java.time.DateTimeException e) {
            return null;
        }
    }

    static LocalTime hora(String texto) {
        Matcher m = HORA.matcher(texto);
        while (m.find()) {
            int h = Integer.parseInt(m.group(1));
            int min = Integer.parseInt(m.group(2));
            if (h < 24 && min < 60) {
                int s = m.group(3) == null ? 0 : Integer.parseInt(m.group(3));
                return LocalTime.of(h, min, Math.min(s, 59));
            }
        }
        return null;
    }

    private static String grupo(Matcher m, String nombre) {
        try {
            String valor = m.group(nombre);
            return valor == null || valor.isBlank() ? null : valor.trim();
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    /** Quita la puntuación final y los espacios de sobra de un nombre. */
    private static String limpiar(String nombre) {
        if (nombre == null) {
            return null;
        }
        return nombre.replaceAll("[\\s.,]+$", "").replaceAll("\\s+", " ").trim();
    }
}
