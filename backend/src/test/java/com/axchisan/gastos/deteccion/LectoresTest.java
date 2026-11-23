package com.axchisan.gastos.deteccion;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Los avisos y extractos de Bancolombia. Las plantillas son las reales, pero todos los nombres,
 * cuentas, llaves e importes son inventados.
 */
@DisplayName("Lectura de avisos y extractos")
class LectoresTest {

    @Nested
    @DisplayName("Importes")
    class ImportesTest {

        @ParameterizedTest
        @CsvSource(delimiter = '|', value = {
                "40,000       | 40000.00",
                "2.000,00     | 2000.00",
                "150000.00    | 150000.00",
                "46,000.00    | 46000.00",
                "9,999,999.99 | 9999999.99",
                "1.234.567,8  | 1234567.80",
                "12.500       | 12500.00",
                "0,99         | 0.99",
                "$ 3.500,00.  | 3500.00",
                "700          | 700.00"})
        void entiende_cada_formato(String texto, BigDecimal esperado) {
            assertThat(Importes.interpretar(texto)).isEqualByComparingTo(esperado);
        }

        @Test
        void lo_que_no_es_un_numero_da_null() {
            assertThat(Importes.interpretar("abc")).isNull();
            assertThat(Importes.interpretar("")).isNull();
            assertThat(Importes.interpretar(null)).isNull();
        }
    }

    @Nested
    @DisplayName("Avisos por correo o SMS")
    class Avisos {

        private AvisoBancario leer(String texto) {
            return LectorAvisosBancolombia.leer(texto).orElseThrow(
                    () -> new AssertionError("No se entendió: " + texto));
        }

        @Test
        void compra_con_tarjeta_debito() {
            AvisoBancario a = leer("Bancolombia: Compraste $12.500,00 en TIENDA LA ESQUINA con "
                    + "tu T.Deb *4321, el 14/08/2026 a las 18:05. Si tienes dudas, encuentranos "
                    + "aqui: 6045109095 o 018000931987. Estamos cerca.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.COMPRA);
            assertThat(a.monto()).isEqualByComparingTo("12500");
            assertThat(a.entra()).isFalse();
            assertThat(a.fecha()).isEqualTo(LocalDate.of(2026, 8, 14));
            assertThat(a.hora()).isEqualTo(LocalTime.of(18, 5));
            assertThat(a.cuenta()).isEqualTo("4321");
            assertThat(a.contraparte()).isEqualTo("TIENDA LA ESQUINA");
        }

        @Test
        void compra_con_el_comercio_pegado_al_con() {
            AvisoBancario a = leer("Bancolombia: Compraste $8.900,00 en PANADERIA SOL123con tu "
                    + "T.Deb *4321, el 02/08/2026 a las 07:41.");
            assertThat(a.contraparte()).isEqualTo("PANADERIA SOL123");
        }

        @Test
        void transferencia_a_otra_cuenta_con_fecha_corta() {
            AvisoBancario a = leer("Bancolombia: Transferiste $150,000.00 desde tu cuenta *1111 a "
                    + "la cuenta *5550001234 el 03/08/26 a las 09:30. ¿Dudas? Llamanos al "
                    + "018000931987. Estamos cerca.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.TRANSFERENCIA_ENVIADA);
            assertThat(a.monto()).isEqualByComparingTo("150000");
            assertThat(a.fecha()).isEqualTo(LocalDate.of(2026, 8, 3));
            assertThat(a.cuenta()).isEqualTo("1111");
            assertThat(a.referencia()).isEqualTo("5550001234");
        }

        @Test
        void transferencia_sin_asterisco_ni_decimales() {
            AvisoBancario a = leer("Bancolombia: Transferiste $40,000 desde tu cuenta 1111 a la "
                    + "cuenta *3001112233 el 05/08/2026 a las 20:10.");
            assertThat(a.monto()).isEqualByComparingTo("40000");
            assertThat(a.cuenta()).isEqualTo("1111");
        }

        @Test
        void transferencia_por_llave_bre_b() {
            AvisoBancario a = leer("Bancolombia: LAURA, transferiste $25,000.00 a la llave "
                    + "3001234567 desde tu cuenta *1111 a MARIO PEREZ el 06/08/26 a las 12:00. "
                    + "Con Bre-b es de una y sin costo.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.TRANSFERENCIA_ENVIADA);
            assertThat(a.referencia()).isEqualTo("3001234567");
            assertThat(a.contraparte()).isEqualTo("MARIO PEREZ");
        }

        @Test
        void transferencia_recibida_por_llave() {
            AvisoBancario a = leer("Bancolombia: LAURA, recibiste una transferencia de Mario Pérez "
                    + "Gómez por $60,000.00 en tu cuenta *1111 conectada a la llave 3009876543 "
                    + "el 07/08/26 a las 16:22.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.TRANSFERENCIA_RECIBIDA);
            assertThat(a.entra()).isTrue();
            assertThat(a.montoConSigno()).isEqualByComparingTo("60000");
            assertThat(a.contraparte()).isEqualTo("Mario Pérez Gómez");
            assertThat(a.referencia()).isEqualTo("3009876543");
        }

        @Test
        void pago_recibido_con_la_hora_antes_que_la_fecha() {
            AvisoBancario a = leer("Bancolombia: Recibiste un pago por $1,200,000.00 de EMPRESA "
                    + "EJEMPLO SAS a tu cuenta AHORROS, el 10:15 a las 08/08/2026. ¿Tienes "
                    + "dudas? Encuentranos aqui:6045109095.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.TRANSFERENCIA_RECIBIDA);
            assertThat(a.fecha()).isEqualTo(LocalDate.of(2026, 8, 8));
            assertThat(a.hora()).isEqualTo(LocalTime.of(10, 15));
            assertThat(a.contraparte()).isEqualTo("EMPRESA EJEMPLO SAS");
        }

        @Test
        void pago_de_nomina() {
            AvisoBancario a = leer("Bancolombia: Recibiste un pago de Nomina de EMPRESA EJEMPLO "
                    + "SAS por $900.000,00 en tu cuenta de Ahorros el 15/08/2026 a las 06:00.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.NOMINA);
            assertThat(a.entra()).isTrue();
            assertThat(a.contraparte()).isEqualTo("EMPRESA EJEMPLO SAS");
        }

        @Test
        void pago_pse_con_segundos() {
            AvisoBancario a = leer("Bancolombia: Pagaste $85,300.00 a Empresa de Energia del "
                    + "Ejemplo desde tu producto *1111 el 09/08/2026 14:03:27. ¿Dudas? Llamanos.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.PAGO);
            assertThat(a.contraparte()).isEqualTo("Empresa de Energia del Ejemplo");
            assertThat(a.hora()).isEqualTo(LocalTime.of(14, 3, 27));
        }

        @Test
        void pago_con_codigo_qr() {
            AvisoBancario a = leer("Bancolombia: LAURA PEREZ pagaste $7,500.00 por codigo QR desde "
                    + "tu cuenta *1111 a la llave 3005556677 el 10/08/2026 a las 11:11.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.PAGO_QR);
            assertThat(a.referencia()).isEqualTo("3005556677");
        }

        @Test
        void transferencia_por_qr_con_fecha_al_reves() {
            AvisoBancario a = leer("Bancolombia: Transferiste $4,000.00 por QR desde tu cuenta 1111 "
                    + "a la cuenta 2222, el 2026/08/11 19:45. ¿Dudas? Llamanos.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.PAGO_QR);
            assertThat(a.fecha()).isEqualTo(LocalDate.of(2026, 8, 11));
            assertThat(a.hora()).isEqualTo(LocalTime.of(19, 45));
        }

        @Test
        void boton_bancolombia() {
            AvisoBancario a = leer("Notificación Transaccional Bancolombia: Transferiste "
                    + "$230,000.00 por Boton Bancolombia a Pasarela Ejemplo SAS desde producto "
                    + "*1111. 12/08/2026 21:00:05 ¿Dudas? 018000931987.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.TRANSFERENCIA_ENVIADA);
            assertThat(a.contraparte()).isEqualTo("Pasarela Ejemplo SAS");
        }

        @Test
        void retiro_en_cajero() {
            AvisoBancario a = leer("Bancolombia: Retiraste $100.000,00 en CAJERO_CENTRO de tu "
                    + "T.Deb **4321 el 13/08/2026 a las 10:00. Si tienes dudas, llamanos.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.RETIRO);
            assertThat(a.cuenta()).isEqualTo("4321");
        }

        @Test
        void los_avisos_que_no_son_movimientos_se_ignoran() {
            List<String> otros = List.of(
                    "Bancolombia: Ups! El pago en TIENDA por $ 20,000 fue rechazada por saldo "
                            + "insuficiente. Tu saldo actual es $ 1,000.",
                    "Bancolombia: 123456 es el codigo para que actives tu billetera.",
                    "Bancolombia: Listo. Te identificaste con tu clave principal el 01/08/2026.",
                    "Bancolombia: Muy pronto cobraremos una suscripción asociada a tu tarjeta.");
            for (String texto : otros) {
                assertThat(LectorAvisosBancolombia.noEsMovimiento(texto)).as(texto).isTrue();
                assertThat(LectorAvisosBancolombia.leer(texto)).as(texto).isEmpty();
            }
        }

        @Test
        void un_texto_desconocido_con_importe_no_se_inventa_pero_tampoco_se_ignora() {
            String nuevo = "Bancolombia: algo nuevo de $5.000";
            assertThat(LectorAvisosBancolombia.leer(nuevo)).isEmpty();
            assertThat(LectorAvisosBancolombia.noEsMovimiento(nuevo)).isFalse();
        }

        @Test
        void sin_importe_no_es_un_movimiento() {
            assertThat(LectorAvisosBancolombia.noEsMovimiento("Bancolombia: Encendiste tu "
                    + "tarjeta debito *4321 el 01/08/2026 a las 10:00.")).isTrue();
            assertThat(LectorAvisosBancolombia.noEsMovimiento("Bancolombia: Recibiras $20.000 en "
                    + "15 dias habiles en tu tarjeta debito *4321 por parte de TIENDA.")).isTrue();
        }

        @Test
        void transferencia_con_espacio_tras_el_asterisco() {
            AvisoBancario a = leer("Bancolombia: Transferiste $70,000 desde tu cuenta *1111 a la "
                    + "cuenta * 30011122233 el 04/08/2026 a las 08:15.");
            assertThat(a.referencia()).isEqualTo("30011122233");
        }

        @Test
        void pago_de_proveedor_recibido() {
            AvisoBancario a = leer("Bancolombia: Recibiste un pago PROVEEDOR de EMPRESA EJEMPLO por "
                    + "$150,000.00 en tu cuenta de Ahorros el 05/08/2026 a las 09:00.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.TRANSFERENCIA_RECIBIDA);
            assertThat(a.contraparte()).isEqualTo("EMPRESA EJEMPLO");
            assertThat(a.monto()).isEqualByComparingTo("150000");
        }

        @Test
        void consignacion_en_corresponsal() {
            AvisoBancario a = leer("Bancolombia: Recibiste una consignacion por $30,000 desde el "
                    + "corresponsal TIENDA DEL BARRIO en CIUDAD, el 06/08/26 17:20.");
            assertThat(a.clase()).isEqualTo(ClaseMovimiento.TRANSFERENCIA_RECIBIDA);
            assertThat(a.entra()).isTrue();
            assertThat(a.fecha()).isEqualTo(LocalDate.of(2026, 8, 6));
        }
    }

    @Nested
    @DisplayName("Extracto en PDF")
    class Extracto {

        private static final String TEXTO = """
                Viernes, 21 de agosto de 2026, 10:00 a. m.
                LAURA PEREZ
                Movimiento: Cuentas
                Cuenta Ahorros
                Ahorros 123 - 456789 - 01
                Fecha Descripción Referencia Valor
                20 ago 2026 ABONO INTERESES AHORROS - $ 1,25
                20 ago 2026 COMPRA EN TIENDA LA ESQUINA - -$ 12.500,00
                19 ago 2026 TRANSFERENCIA DESDE NEQUI 3001112233 $ 200.000,00
                19 ago 2026 TRANSFERENCIAS A NEQUI 3004445566 -$ 50.000,00
                Dirección IP: 10.0.0.1
                Fecha Descripción Referencia Valor
                18 ago 2026 TRANSF A PASARELA EJEMPLO 1234567 7654321098 55555 -$ 230.000,00
                18 ago 2026 TRANSF DE EMPRESA EJEMPLO SAS null $ 1.200.000,00
                17 ago 2026 PAGO PSE Empresa de Energia 123456789 -$ 85.300,00
                17 ago 2026 PAGO QR PANADERIA SOL 3005556677 -$ 7.500,00
                16 sept 2026 Retiro Cajero ATM CENTRO - -$ 100.000,00
                16 ago 2026 COMISION RETIRO CAJERO/CB - -$ 2.500,00
                15 ago 2026 PAGO DE NOMI EMPRESA EJEMPLO 999 $ 900.000,00
                """;

        @Test
        void lee_cada_linea_y_la_cuenta() {
            LectorExtractoBancolombia.Extracto e = LectorExtractoBancolombia.leerTexto(TEXTO);
            assertThat(e.cuenta()).isEqualTo("8901");
            assertThat(e.titular()).isEqualTo("LAURA PEREZ");
            assertThat(e.lineas()).hasSize(11);
            assertThat(e.lineas()).extracting(l -> l.aviso().clase()).containsExactly(
                    ClaseMovimiento.INTERESES, ClaseMovimiento.COMPRA,
                    ClaseMovimiento.TRANSFERENCIA_RECIBIDA,
                    ClaseMovimiento.TRANSFERENCIA_ENVIADA,
                    ClaseMovimiento.TRANSFERENCIA_ENVIADA,
                    ClaseMovimiento.TRANSFERENCIA_RECIBIDA, ClaseMovimiento.PAGO,
                    ClaseMovimiento.PAGO_QR, ClaseMovimiento.RETIRO, ClaseMovimiento.COMISION,
                    ClaseMovimiento.NOMINA);
        }

        @Test
        void separa_descripcion_referencia_y_valor() {
            var lineas = LectorExtractoBancolombia.leerTexto(TEXTO).lineas();
            AvisoBancario compra = lineas.get(1).aviso();
            assertThat(compra.contraparte()).isEqualTo("TIENDA LA ESQUINA");
            assertThat(compra.referencia()).isNull();
            assertThat(compra.montoConSigno()).isEqualByComparingTo("-12500");
            assertThat(compra.fecha()).isEqualTo(LocalDate.of(2026, 8, 20));
            assertThat(compra.hora()).isNull();

            AvisoBancario nequi = lineas.get(2).aviso();
            assertThat(nequi.contraparte()).isEqualTo("Nequi");
            assertThat(nequi.referencia()).isEqualTo("3001112233");
            assertThat(nequi.entra()).isTrue();

            AvisoBancario pasarela = lineas.get(4).aviso();
            assertThat(pasarela.contraparte()).isEqualTo("PASARELA EJEMPLO");
            assertThat(pasarela.referencia()).isEqualTo("1234567 7654321098 55555");

            AvisoBancario empresa = lineas.get(5).aviso();
            assertThat(empresa.contraparte()).isEqualTo("EMPRESA EJEMPLO SAS");
            assertThat(empresa.referencia()).isNull();
            assertThat(lineas.get(8).aviso().fecha()).isEqualTo(LocalDate.of(2026, 9, 16));
        }

        @Test
        void une_las_descripciones_partidas_en_varios_renglones() {
            String partido = """
                    Ahorros 123 - 456789 - 01
                    Fecha Descripción Referencia Valor
                    20 ago 2026
                    PAGO PSE EMPRESA DE
                    ENERGIA DEL EJEMPLO
                    123456789 -$ 85.300,00
                    20 ago 2026 COMPRA EN TIENDA - -$ 2.000,00
                    19 ago 2026
                    PAGO QR PANADERIA
                    - -$ 7.500,00
                    Dirección IP: 10.0.0.1
                    Fecha Descripción Referencia Valor
                    18 ago 2026 TRANSF DE MARIO null $ 60.000,00
                    """;
            var lineas = LectorExtractoBancolombia.leerTexto(partido).lineas();
            assertThat(lineas).hasSize(4);
            assertThat(lineas.get(0).aviso().contraparte()).isEqualTo("EMPRESA DE ENERGIA DEL EJEMPLO");
            assertThat(lineas.get(0).aviso().referencia()).isEqualTo("123456789");
            assertThat(lineas.get(0).aviso().clase()).isEqualTo(ClaseMovimiento.PAGO);
            assertThat(lineas.get(2).aviso().contraparte()).isEqualTo("PANADERIA");
            assertThat(lineas.get(3).aviso().montoConSigno()).isEqualByComparingTo("60000");
        }

        @Test
        void lee_un_pdf_de_verdad() throws Exception {
            byte[] pdf = pdfCon(List.of("Ahorros 123 - 456789 - 01",
                    "Fecha Descripción Referencia Valor",
                    "20 ago 2026 COMPRA EN TIENDA LA ESQUINA - -$ 12.500,00",
                    "19 ago 2026 TRANSFERENCIA DESDE NEQUI 3001112233 $ 200.000,00"));
            LectorExtractoBancolombia.Extracto e = LectorExtractoBancolombia.leer(pdf);
            assertThat(e.cuenta()).isEqualTo("8901");
            assertThat(e.lineas()).hasSize(2);
            assertThat(e.lineas().get(1).aviso().monto()).isEqualByComparingTo("200000");
        }

        @Test
        void lo_que_no_es_pdf_se_rechaza() {
            assertThatThrownBy(() -> LectorExtractoBancolombia.leer("hola".getBytes()))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    /** Un PDF de una página con esas líneas de texto. */
    static byte[] pdfCon(List<String> lineas) throws Exception {
        try (PDDocument doc = new PDDocument()) {
            PDPage pagina = new PDPage();
            doc.addPage(pagina);
            try (PDPageContentStream s = new PDPageContentStream(doc, pagina)) {
                s.beginText();
                s.setFont(new PDType1Font(Standard14Fonts.FontName.HELVETICA), 10);
                s.setLeading(14);
                s.newLineAtOffset(40, 740);
                for (String l : lineas) {
                    s.showText(l);
                    s.newLine();
                }
                s.endText();
            }
            ByteArrayOutputStream salida = new ByteArrayOutputStream();
            doc.save(salida);
            return salida.toByteArray();
        }
    }
}
