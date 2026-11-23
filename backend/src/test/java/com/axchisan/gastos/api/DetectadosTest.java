package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MovimientoDetectadoRepository;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.ReglaDeteccionRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.io.ByteArrayOutputStream;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * La bandeja de movimientos detectados. Cifras, nombres y cuentas inventados; el mes de agosto
 * de 2026 va del 28 de julio al 27 de agosto.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Movimientos detectados")
class DetectadosTest {

    private static final String PASSWORD = "unaClaveSegura123";

    private static final String SMS_COMPRA = "Bancolombia: Compraste $12.500,00 en TIENDA LA "
            + "ESQUINA con tu T.Deb *4321, el 14/08/2026 a las 18:05. Si tienes dudas, llamanos.";
    private static final String CORREO_COMPRA = "Bancolombia: Compraste $12.500,00 en TIENDA LA "
            + "ESQUINA con tu T.Deb *4321, el 14/08/2026 a las 18:05. Estamos cerca.";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private CompraRepository compras;
    @Autowired private MovimientoDetectadoRepository detectados;
    @Autowired private ReglaDeteccionRepository reglas;

    private String token;
    private UUID agosto;

    @BeforeEach
    void preparar() throws Exception {
        detectados.deleteAll();
        reglas.deleteAll();
        compras.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar("ana@ejemplo.co");
        agosto = crearMes(2026, 8, 1000000);
    }

    @Test
    void un_aviso_queda_pendiente_con_una_sugerencia() throws Exception {
        JsonNode r = aviso("SMS", SMS_COMPRA, 201);
        assertThat(r.get("resultado").asText()).isEqualTo("NUEVO");
        JsonNode d = r.get("detectado");
        assertThat(d.get("estado").asText()).isEqualTo("PENDIENTE");
        assertThat(d.get("clase").asText()).isEqualTo("COMPRA");
        assertThat(d.get("monto").decimalValue()).isEqualByComparingTo("-12500");
        assertThat(d.get("hora").asText()).startsWith("18:05");
        assertThat(d.get("sugerenciaDestino").asText()).isEqualTo("COMPRA");

        assertThat(bandeja()).hasSize(1);
    }

    @Test
    void el_mismo_aviso_dos_veces_se_guarda_una_sola() throws Exception {
        aviso("SMS", SMS_COMPRA, 201);
        JsonNode otraVez = aviso("SMS", "  " + SMS_COMPRA.replace(" en ", "  en ") + " ", 200);
        assertThat(otraVez.get("resultado").asText()).isEqualTo("REPETIDO");
        assertThat(bandeja()).hasSize(1);
    }

    @Test
    void el_mismo_movimiento_por_correo_y_sms_es_un_duplicado() throws Exception {
        aviso("SMS", SMS_COMPRA, 201);
        JsonNode correo = aviso("CORREO", CORREO_COMPRA, 201).get("detectado");
        assertThat(correo.get("estado").asText()).isEqualTo("DUPLICADO");
        assertThat(correo.get("motivo").asText()).isEqualTo("Ya llegó por sms");
        assertThat(bandeja()).hasSize(1);
    }

    @Test
    void dos_compras_iguales_el_mismo_dia_no_se_comen() throws Exception {
        aviso("SMS", SMS_COMPRA, 201);
        aviso("SMS", SMS_COMPRA.replace("18:05", "19:40"), 201);
        assertThat(bandeja()).hasSize(2);
        // El correo de la primera es duplicado de una; el de la segunda, de la otra.
        aviso("CORREO", CORREO_COMPRA, 201);
        aviso("CORREO", CORREO_COMPRA.replace("18:05", "19:40"), 201);
        assertThat(bandeja()).hasSize(2);
        JsonNode todos = listar("?estado=DUPLICADO");
        assertThat(todos).hasSize(2);
        assertThat(todos.get(0).get("duplicadoDe").asText())
                .isNotEqualTo(todos.get(1).get("duplicadoDe").asText());
    }

    @Test
    void lo_que_ya_estaba_apuntado_no_se_propone() throws Exception {
        enviar(post("/api/meses/" + agosto + "/compras"), """
                {"descripcion":"Mercado","monto":12500,"categoria":"ALIMENTACION",
                 "fecha":"2026-08-15","medio":"DEBITO"}
                """);
        JsonNode d = aviso("SMS", SMS_COMPRA, 201).get("detectado");
        assertThat(d.get("estado").asText()).isEqualTo("YA_REGISTRADO");
        assertThat(d.get("coincideTipo").asText()).isEqualTo("COMPRA");
        assertThat(d.get("motivo").asText()).isEqualTo("Ya está: Mercado");

        // Una segunda compra igual ya no puede reclamar la misma compra apuntada.
        JsonNode otra = aviso("SMS", SMS_COMPRA.replace("18:05", "19:40"), 201).get("detectado");
        assertThat(otra.get("estado").asText()).isEqualTo("PENDIENTE");
    }

    @Test
    void los_avisos_que_no_son_movimientos_ni_se_guardan() throws Exception {
        JsonNode r = aviso("SMS", "Bancolombia: 123456 es el codigo para que actives tu "
                + "billetera. No lo compartas.", 200);
        assertThat(r.get("resultado").asText()).isEqualTo("IGNORADO");
        assertThat(detectados.count()).isZero();
    }

    @Test
    void un_aviso_desconocido_se_guarda_aparte_para_revisar_la_plantilla() throws Exception {
        JsonNode d = aviso("CORREO", "Bancolombia: algo nuevo pasó con $5.000", 201)
                .get("detectado");
        assertThat(d.get("estado").asText()).isEqualTo("NO_RECONOCIDO");
        assertThat(bandeja()).isEmpty();
        assertThat(listar("?estado=NO_RECONOCIDO")).hasSize(1);
    }

    @Test
    void las_reglas_descartan_y_sugieren_incluso_lo_que_ya_estaba_pendiente() throws Exception {
        String recibida = "Bancolombia: ANA, recibiste una transferencia de Mario Pérez por "
                + "$60,000.00 en tu cuenta *1111 conectada a la llave 3009876543 el 07/08/26 a "
                + "las 16:22.";
        String propia = "Bancolombia: ANA, transferiste $50,000.00 a la llave 3001112233 desde "
                + "tu cuenta *1111 a ANA RUIZ el 08/08/26 a las 10:00.";
        aviso("SMS", recibida, 201);
        aviso("SMS", propia, 201);
        assertThat(bandeja()).hasSize(2);

        enviar(post("/api/detectados/reglas"), """
                {"campo":"REFERENCIA","valor":"300 111 2233","accion":"DESCARTAR",
                 "nombre":"Cuenta propia"}
                """);
        String regla = id(enviar(post("/api/detectados/reglas"), """
                {"campo":"CONTRAPARTE","valor":"mario perez","accion":"SUGERIR",
                 "destino":"INGRESO","categoria":"FAMILIA","nombre":"Apoyo de Mario"}
                """));

        JsonNode quedan = bandeja();
        assertThat(quedan).hasSize(1);
        assertThat(quedan.get(0).get("sugerenciaNombre").asText()).isEqualTo("Apoyo de Mario");
        assertThat(quedan.get(0).get("sugerenciaCategoria").asText()).isEqualTo("FAMILIA");
        JsonNode descartado = listar("?estado=DESCARTADO").get(0);
        assertThat(descartado.get("motivo").asText()).isEqualTo("Cuenta propia");

        // Las reglas también se aplican a lo que llega después.
        aviso("SMS", propia.replace("10:00", "11:00").replace("08/08/26", "09/08/26"), 201);
        assertThat(bandeja()).hasSize(1);

        mvc.perform(auth(delete("/api/detectados/reglas/" + regla)))
                .andExpect(status().isNoContent());
        assertThat(json.readTree(mvc.perform(auth(get("/api/detectados/reglas")))
                .andReturn().getResponse().getContentAsString())).hasSize(1);
    }

    @Test
    void descartar_marcar_y_reabrir() throws Exception {
        String id = aviso("SMS", SMS_COMPRA, 201).get("detectado").get("id").asText();
        JsonNode d = json.readTree(enviar(post("/api/detectados/" + id + "/descartar"),
                "{\"motivo\":\"No era mío\"}").getResponse().getContentAsString());
        assertThat(d.get("estado").asText()).isEqualTo("DESCARTADO");
        assertThat(bandeja()).isEmpty();

        enviar(post("/api/detectados/" + id + "/reabrir"), "{}");
        assertThat(bandeja()).hasSize(1);

        d = json.readTree(enviar(post("/api/detectados/" + id + "/ya-registrado"), "{}")
                .getResponse().getContentAsString());
        assertThat(d.get("estado").asText()).isEqualTo("YA_REGISTRADO");
        assertThat(bandeja()).isEmpty();
    }

    @Test
    void el_extracto_completa_lo_que_no_llego_y_no_repite_nada() throws Exception {
        aviso("SMS", SMS_COMPRA, 201);
        byte[] pdf = pdfCon(List.of(
                "Ahorros 123 - 456789 - 01",
                "Fecha Descripción Referencia Valor",
                "15 ago 2026 TRANSFERENCIA DESDE NEQUI 3001112233 $ 200.000,00",
                "15 ago 2026 ABONO INTERESES AHORROS - $ 1,25",
                "14 ago 2026 COMPRA EN TIENDA LA ESQUINA - -$ 12.500,00",
                "13 ago 2026 COMPRA EN PAPELERIA - -$ 3.000,00",
                "13 ago 2026 COMPRA EN PAPELERIA - -$ 3.000,00",
                "12 ago 2026 Retiro Cajero ATM CENTRO - -$ 100.000,00"));
        JsonNode r = importar(pdf);
        assertThat(r.get("cuenta").asText()).isEqualTo("8901");
        assertThat(r.get("leidos").asInt()).isEqualTo(6);
        assertThat(r.get("duplicados").asInt()).isEqualTo(1);
        assertThat(r.get("descartados").asInt()).isEqualTo(2);
        assertThat(r.get("pendientes").asInt()).isEqualTo(3);
        assertThat(r.get("desde").asText()).isEqualTo("2026-08-12");
        assertThat(r.get("hasta").asText()).isEqualTo("2026-08-15");
        // La compra del SMS, lo de Nequi y las dos compras iguales en la papelería.
        assertThat(bandeja()).hasSize(4);

        // Importar el mismo PDF otra vez no agrega nada.
        JsonNode otraVez = importar(pdf);
        assertThat(otraVez.get("yaEstaban").asInt()).isEqualTo(6);
        assertThat(otraVez.get("pendientes").asInt()).isZero();
        assertThat(bandeja()).hasSize(4);
    }

    @Test
    void un_archivo_que_no_es_el_extracto_se_rechaza() throws Exception {
        mvc.perform(auth(post("/api/detectados/extractos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"pdf\":\"" + Base64.getEncoder().encodeToString(
                                "no soy un pdf".getBytes()) + "\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(auth(post("/api/detectados/extractos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"pdf\":\"" + Base64.getEncoder().encodeToString(
                                pdfCon(List.of("Un documento cualquiera"))) + "\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cada_usuario_ve_solo_lo_suyo() throws Exception {
        String id = aviso("SMS", SMS_COMPRA, 201).get("detectado").get("id").asText();
        token = registrar("otro@ejemplo.co");
        assertThat(bandeja()).isEmpty();
        mvc.perform(auth(post("/api/detectados/" + id + "/descartar")))
                .andExpect(status().isNotFound());
    }

    // --- ayudantes ---

    private JsonNode aviso(String origen, String texto, int estado) throws Exception {
        MvcResult r = mvc.perform(auth(post("/api/detectados/avisos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(
                                java.util.Map.of("origen", origen, "texto", texto))))
                .andReturn();
        assertThat(r.getResponse().getStatus()).as(r.getResponse().getContentAsString())
                .isEqualTo(estado);
        return json.readTree(r.getResponse().getContentAsString());
    }

    private JsonNode importar(byte[] pdf) throws Exception {
        return json.readTree(enviar(post("/api/detectados/extractos"),
                "{\"pdf\":\"" + Base64.getEncoder().encodeToString(pdf) + "\"}")
                .getResponse().getContentAsString());
    }

    private JsonNode bandeja() throws Exception {
        return listar("");
    }

    private JsonNode listar(String filtro) throws Exception {
        return json.readTree(mvc.perform(auth(get("/api/detectados" + filtro)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private static byte[] pdfCon(List<String> lineas) throws Exception {
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

    private UUID crearMes(int anio, int mes, int sueldo) throws Exception {
        return UUID.fromString(id(enviar(post("/api/meses"), "{\"anio\":" + anio + ",\"mes\":"
                + mes + ",\"ingresoBase\":" + sueldo + ",\"copiarPlantillas\":false}")));
    }

    private String id(MvcResult resultado) throws Exception {
        return json.readTree(resultado.getResponse().getContentAsString()).get("id").asText();
    }

    private MvcResult enviar(MockHttpServletRequestBuilder peticion, String cuerpo)
            throws Exception {
        MvcResult resultado = mvc.perform(auth(peticion)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andReturn();
        assertThat(resultado.getResponse().getStatus())
                .as(resultado.getResponse().getContentAsString())
                .isBetween(200, 299);
        return resultado;
    }

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder peticion) {
        return peticion.header("Authorization", "Bearer " + token);
    }

    private String registrar(String email) throws Exception {
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"" + PASSWORD
                                + "\",\"nombre\":\"Prueba\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }
}
