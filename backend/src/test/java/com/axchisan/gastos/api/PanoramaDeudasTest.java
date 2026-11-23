package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CreditoRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

/**
 * Todo lo que se debe y cómo baja. Cifras inventadas; el día de referencia es el 20 de agosto de
 * 2026.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Panorama de deudas")
class PanoramaDeudasTest {

    private static final String PASSWORD = "unaClaveSegura123";
    private static final String HOY = "2026-08-20";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private DeudaRepository deudas;
    @Autowired private CreditoRepository creditos;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        deudas.deleteAll();
        creditos.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();
    }

    /** Un crédito a tres cuotas con la primera pagada: debe 200.000 y termina en octubre. */
    private void crearCredito() throws Exception {
        enviar(post("/api/creditos"), """
                {"entidad":"Banco Uno","montoOriginal":300000,"tasaEa":30.0,"plazoCuotas":3,
                 "cuotas":[
                   {"numero":1,"fecha":"2026-08-10","saldoCapital":300000,"capital":100000,
                    "interes":5000,"valorCuota":105000,"pagada":true,"fechaPago":"2026-08-10"},
                   {"numero":2,"fecha":"2026-09-10","saldoCapital":200000,"capital":100000,
                    "interes":3000,"valorCuota":103000},
                   {"numero":3,"fecha":"2026-10-10","saldoCapital":100000,"capital":100000,
                    "interes":1500,"valorCuota":101500}
                 ]}
                """);
    }

    private void crearDeudas() throws Exception {
        // Con cuota mensual de 30.000: paga en sep, oct y nov.
        enviar(post("/api/deudas"), """
                {"acreedor":"Tío","tipo":"FAMILIAR","montoOriginal":90000,
                 "fechaInicio":"2026-07-01","cuotaSugerida":30000}
                """);
        // Pago único el 4 de septiembre.
        enviar(post("/api/deudas"), """
                {"acreedor":"Prestamista","tipo":"PRESTAMO_BANCARIO","montoOriginal":50000,
                 "fechaInicio":"2026-08-01","fechaLimite":"2026-09-04"}
                """);
    }

    @Test
    void suma_creditos_y_deudas_y_proyecta_como_bajan() throws Exception {
        crearCredito();
        crearDeudas();

        JsonNode p = leer();
        assertThat(p.get("total").decimalValue()).isEqualByComparingTo("340000");

        List<String> serie = new ArrayList<>();
        p.get("proyeccion").forEach(x -> serie.add(x.get("mes").asText() + " "
                + x.get("total").decimalValue().stripTrailingZeros().toPlainString()));
        assertThat(serie).containsExactly(
                "2026-08 340000", "2026-09 340000", "2026-10 160000", "2026-11 30000",
                "2026-12 0");
        assertThat(p.get("terminaTodoEn").asText()).isEqualTo("2026-11");

        JsonNode credito = parte(p, "Banco Uno");
        assertThat(credito.get("origen").asText()).isEqualTo("CREDITO");
        assertThat(credito.get("saldo").decimalValue()).isEqualByComparingTo("200000");
        assertThat(credito.get("terminaEn").asText()).isEqualTo("2026-10");
        assertThat(credito.get("proximoPago").asText()).isEqualTo("2026-09-10");
        assertThat(credito.get("proximoMonto").decimalValue()).isEqualByComparingTo("103000");
        assertThat(credito.get("cuotas").asText()).isEqualTo("Cuota 2 de 3");
        assertThat(credito.get("progreso").decimalValue()).isEqualByComparingTo("0.3333");

        JsonNode tio = parte(p, "Tío");
        assertThat(tio.get("terminaEn").asText()).isEqualTo("2026-11");
        assertThat(tio.get("proximoMonto").decimalValue()).isEqualByComparingTo("30000");

        JsonNode unico = parte(p, "Prestamista");
        assertThat(unico.get("terminaEn").asText()).isEqualTo("2026-09");
        assertThat(unico.get("proximoPago").asText()).isEqualTo("2026-09-04");

        // Ordenadas por lo que se debe.
        assertThat(p.get("partes").get(0).get("nombre").asText()).isEqualTo("Banco Uno");
    }

    @Test
    void una_deuda_sin_cuota_ni_fecha_no_deja_saber_cuando_se_termina() throws Exception {
        enviar(post("/api/deudas"), """
                {"acreedor":"Amiga","tipo":"AMIGO","montoOriginal":40000,
                 "fechaInicio":"2026-07-01"}
                """);
        JsonNode p = leer();
        assertThat(parte(p, "Amiga").get("sinPlan").asBoolean()).isTrue();
        assertThat(p.has("terminaTodoEn")).isFalse();
        assertThat(p.get("proyeccion").get(5).get("total").decimalValue())
                .isEqualByComparingTo("40000");
    }

    @Test
    void lo_ya_pagado_aparece_como_saldado() throws Exception {
        String id = json.readTree(enviar(post("/api/deudas"), """
                {"acreedor":"Vecino","tipo":"AMIGO","montoOriginal":10000,
                 "fechaInicio":"2026-07-01"}
                """).getResponse().getContentAsString()).get("id").asText();
        enviar(post("/api/deudas/" + id + "/abonos"),
                "{\"monto\":10000,\"fecha\":\"2026-08-15\"}");

        JsonNode p = leer();
        assertThat(p.get("total").decimalValue()).isEqualByComparingTo("0");
        assertThat(p.get("partes")).isEmpty();
        assertThat(p.get("saldadas").get(0).get("nombre").asText()).isEqualTo("Vecino");
    }

    @Test
    void la_deuda_total_del_resumen_ya_cuenta_los_creditos() throws Exception {
        crearCredito();
        crearDeudas();
        String mes = json.readTree(enviar(post("/api/meses"),
                        "{\"anio\":2026,\"mes\":8,\"ingresoBase\":1000000,"
                                + "\"copiarPlantillas\":false}")
                .getResponse().getContentAsString()).get("id").asText();

        mvc.perform(auth(get("/api/meses/" + mes + "/resumen")))
                .andExpect(jsonPath("$.deudaTotal").value(340000))
                .andExpect(jsonPath("$.patrimonioNeto").value(-340000));
    }

    // --- ayudas ---

    private JsonNode leer() throws Exception {
        return json.readTree(mvc.perform(auth(get("/api/deudas/panorama?fecha=" + HOY)))
                .andReturn().getResponse().getContentAsString());
    }

    private static JsonNode parte(JsonNode p, String nombre) {
        for (JsonNode x : p.get("partes")) {
            if (x.get("nombre").asText().equals(nombre)) {
                return x;
            }
        }
        throw new AssertionError("No está: " + nombre);
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

    private String registrar() throws Exception {
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"ana@ejemplo.co\",\"password\":\"" + PASSWORD
                                + "\",\"nombre\":\"Prueba\"}"))
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }
}
