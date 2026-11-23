package com.axchisan.gastos.deteccion;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.DateTimeException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Lee el PDF «Movimientos» que se descarga de la app Mi Bancolombia o de la Sucursal Virtual.
 *
 * <p>Es la única fuente con el 100 % de los movimientos (incluidos los que llegan desde Nequi,
 * que Bancolombia nunca avisa), pero sin hora. Cada movimiento ocupa una línea:
 * {@code 14 nov 2026 COMPRA EN TIENDA X - -$ 12.500,00}: fecha, descripción, referencia (un
 * número, varios, {@code -} o {@code null}) y valor, negativo si sale. Entre páginas se repiten
 * la cabecera de columnas y la dirección IP, que se ignoran.
 *
 * <p>Las descripciones largas ocupan dos o tres renglones dentro de su celda. Por eso el texto
 * se saca en el orden del documento (no por posición, que deja la línea de la fecha en medio de
 * los trozos de la descripción), se junta todo y se corta por cada fecha.
 */
public final class LectorExtractoBancolombia {

    /** Una línea del extracto ya interpretada, con la descripción tal cual para la huella. */
    public record Linea(AvisoBancario aviso, String descripcion) {
    }

    /** El extracto: la cuenta a la que pertenece y sus movimientos, del más reciente al más viejo. */
    public record Extracto(String cuenta, List<Linea> lineas) {
    }

    private static final Pattern MOVIMIENTO = Pattern.compile(
            "(?<![\\d,])(?<dia>\\d{1,2}) (?<mes>ene|feb|mar|abr|may|jun|jul|ago|sept?|oct|nov|dic)"
                    + "\\.? (?<anio>\\d{4}) (?<resto>.+?) (?<signo>-?)\\$ ?"
                    + "(?<valor>\\d[\\d.]*,\\d{2})(?![\\d])",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern REFERENCIA_FINAL =
            Pattern.compile("^(?<desc>.+?)(?:\\s+(?<ref>-|null|\\d+(?:\\s+\\d+)*))?$");
    private static final Pattern CUENTA = Pattern.compile(
            "(?:Ahorros|Corriente)\\s+(\\d{3})\\s*-\\s*(\\d{6})\\s*-\\s*(\\d{2})");

    private static final Map<String, Integer> MESES = Map.ofEntries(
            Map.entry("ene", 1), Map.entry("feb", 2), Map.entry("mar", 3), Map.entry("abr", 4),
            Map.entry("may", 5), Map.entry("jun", 6), Map.entry("jul", 7), Map.entry("ago", 8),
            Map.entry("sep", 9), Map.entry("sept", 9), Map.entry("oct", 10),
            Map.entry("nov", 11), Map.entry("dic", 12));

    private LectorExtractoBancolombia() {
    }

    /** Saca el texto del PDF. Lanza {@link IllegalArgumentException} si no es un PDF legible. */
    public static String texto(byte[] pdf) {
        try (PDDocument documento = Loader.loadPDF(pdf)) {
            PDFTextStripper extractor = new PDFTextStripper();
            extractor.setSortByPosition(false);
            return extractor.getText(documento);
        } catch (IOException e) {
            throw new IllegalArgumentException("El archivo no es un PDF que se pueda leer", e);
        }
    }

    public static Extracto leer(byte[] pdf) {
        return leerTexto(texto(pdf));
    }

    public static Extracto leerTexto(String texto) {
        String cuenta = null;
        Matcher c = CUENTA.matcher(texto);
        if (c.find()) {
            String digitos = c.group(1) + c.group(2) + c.group(3);
            // Los avisos nombran la cuenta por sus cuatro últimos dígitos.
            cuenta = digitos.substring(digitos.length() - 4);
        }
        List<Linea> lineas = new ArrayList<>();
        Matcher m = MOVIMIENTO.matcher(texto.replaceAll("\\s+", " "));
        while (m.find()) {
            LocalDate fecha = fecha(m.group("dia"), m.group("mes"), m.group("anio"));
            BigDecimal valor = Importes.interpretar(m.group("valor"));
            if (fecha == null || valor == null || valor.signum() == 0) {
                continue;
            }
            boolean entra = m.group("signo").isEmpty();
            String resto = m.group("resto").trim();
            Matcher r = REFERENCIA_FINAL.matcher(resto);
            String descripcion = resto;
            String referencia = null;
            if (r.matches()) {
                descripcion = r.group("desc").trim();
                String ref = r.group("ref");
                referencia = ref == null || ref.equals("-") || ref.equals("null") ? null : ref;
            }
            lineas.add(new Linea(interpretar(descripcion, referencia, entra, valor, fecha, cuenta),
                    resto));
        }
        return new Extracto(cuenta, lineas);
    }

    private static AvisoBancario interpretar(String descripcion, String referencia, boolean entra,
                                             BigDecimal valor, LocalDate fecha, String cuenta) {
        String d = descripcion.toUpperCase(Locale.ROOT);
        ClaseMovimiento clase;
        String contraparte;
        if (d.startsWith("ABONO INTERESES")) {
            clase = ClaseMovimiento.INTERESES;
            contraparte = "Intereses";
        } else if (d.startsWith("PAGO DE NOMI")) {
            clase = ClaseMovimiento.NOMINA;
            contraparte = resto(descripcion, "PAGO DE NOMINA", "PAGO DE NOMI");
        } else if (d.startsWith("COMPRA EN ") || d.startsWith("COMPRA INTL ")) {
            clase = ClaseMovimiento.COMPRA;
            contraparte = resto(descripcion, "COMPRA EN", "COMPRA INTL");
        } else if (d.startsWith("PAGO QR ")) {
            clase = ClaseMovimiento.PAGO_QR;
            contraparte = resto(descripcion, "PAGO QR");
        } else if (d.startsWith("PAGO PSE ")) {
            clase = ClaseMovimiento.PAGO;
            contraparte = resto(descripcion, "PAGO PSE");
        } else if (d.startsWith("RETIRO CAJERO")) {
            clase = ClaseMovimiento.RETIRO;
            contraparte = "Cajero";
        } else if (d.startsWith("COMISION") || d.startsWith("CUOTA MANEJO")
                || d.startsWith("IVA ") || d.startsWith("GMF")) {
            clase = ClaseMovimiento.COMISION;
            contraparte = descripcion;
        } else if (d.contains("NEQUI")) {
            clase = entra ? ClaseMovimiento.TRANSFERENCIA_RECIBIDA
                    : ClaseMovimiento.TRANSFERENCIA_ENVIADA;
            contraparte = "Nequi";
        } else if (d.startsWith("TRANSF DE ")) {
            clase = ClaseMovimiento.TRANSFERENCIA_RECIBIDA;
            contraparte = resto(descripcion, "TRANSF DE");
        } else if (d.startsWith("TRANSF A ")) {
            clase = ClaseMovimiento.TRANSFERENCIA_ENVIADA;
            contraparte = resto(descripcion, "TRANSF A");
        } else {
            clase = entra ? ClaseMovimiento.TRANSFERENCIA_RECIBIDA
                    : ClaseMovimiento.TRANSFERENCIA_ENVIADA;
            contraparte = descripcion;
        }
        // El signo del extracto manda: si la descripción engaña, se corrige por él.
        if (clase.entra() != entra) {
            clase = entra ? ClaseMovimiento.TRANSFERENCIA_RECIBIDA : ClaseMovimiento.PAGO;
        }
        return new AvisoBancario(LectorAvisosBancolombia.BANCO, clase, valor, fecha, null, cuenta,
                contraparte, referencia);
    }

    private static String resto(String descripcion, String... prefijos) {
        String d = descripcion.toUpperCase(Locale.ROOT);
        for (String p : prefijos) {
            if (d.startsWith(p)) {
                String r = descripcion.substring(p.length()).trim();
                return r.isEmpty() ? descripcion : r;
            }
        }
        return descripcion;
    }

    private static LocalDate fecha(String dia, String mes, String anio) {
        Integer m = MESES.get(mes.toLowerCase(Locale.ROOT));
        if (m == null) {
            return null;
        }
        try {
            return LocalDate.of(Integer.parseInt(anio), m, Integer.parseInt(dia));
        } catch (DateTimeException e) {
            return null;
        }
    }
}
