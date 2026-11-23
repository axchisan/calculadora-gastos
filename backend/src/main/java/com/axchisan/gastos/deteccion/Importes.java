package com.axchisan.gastos.deteccion;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Interpreta importes escritos de cualquiera de las formas que usan los bancos colombianos:
 * {@code 40,000} · {@code 2.000,00} · {@code 150000.00} · {@code 46,000.00} · {@code 9,999,999.99}.
 */
public final class Importes {

    private Importes() {
    }

    /**
     * Regla: si hay punto y coma, el último que aparece es el separador decimal. Si solo hay uno
     * de los dos, es decimal cuando lo siguen exactamente uno o dos dígitos al final; si lo siguen
     * tres, separa miles.
     *
     * @return el importe con dos decimales, o null si no es un número
     */
    public static BigDecimal interpretar(String texto) {
        if (texto == null) {
            return null;
        }
        String t = texto.replaceAll("[\\s$]", "").replaceAll("[.,]+$", "");
        if (t.isEmpty() || !t.matches("[\\d.,]+")) {
            return null;
        }
        int punto = t.lastIndexOf('.');
        int coma = t.lastIndexOf(',');
        String normal;
        if (punto >= 0 && coma >= 0) {
            char decimal = punto > coma ? '.' : ',';
            char miles = decimal == '.' ? ',' : '.';
            normal = t.replace(String.valueOf(miles), "").replace(decimal, '.');
        } else if (punto >= 0 || coma >= 0) {
            char sep = punto >= 0 ? '.' : ',';
            int ultimo = Math.max(punto, coma);
            int decimales = t.length() - ultimo - 1;
            boolean unico = t.indexOf(sep) == ultimo;
            if (unico && decimales >= 1 && decimales <= 2) {
                normal = t.replace(sep, '.');
            } else {
                normal = t.replace(String.valueOf(sep), "");
            }
        } else {
            normal = t;
        }
        try {
            return new BigDecimal(normal).setScale(2, RoundingMode.HALF_UP);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
