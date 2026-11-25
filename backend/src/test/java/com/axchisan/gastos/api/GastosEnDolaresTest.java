package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.PlantillaGastoRepository;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Gastos fijos que se cobran en dólares y siguen a la TRM del sueldo. Cifras inventadas. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Gastos en dólares")
class GastosEnDolaresTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private PlantillaGastoRepository plantillas;
    @Autowired private FuenteIngresoRepository fuentes;

    private String token;
    private String fuente;

    @BeforeEach
    void preparar() throws Exception {
        plantillas.deleteAll();
        fuentes.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();
        // La TRM la pone la fuente de ingreso en dólares: 4.000 pesos por dólar.
        fuente = id(enviar(post("/api/sueldo"), """
                {"nombre":"Empresa","montoMensual":500,"fechaInicio":"2026-07-01",
                 "medio":"TRANSFERENCIA","trm":4000}
                """));
    }

    @Test
    void la_plantilla_en_dolares_se_pasa_a_pesos_con_la_trm() throws Exception {
        JsonNode p = json.readTree(enviar(post("/api/plantillas"), """
                {"nombre":"Suscripción","categoria":"HERRAMIENTAS","montoDefault":0,
                 "diaVencimiento":2,"montoUsd":20}
                """).getResponse().getContentAsString());
        assertThat(p.get("montoUsd").decimalValue()).isEqualByComparingTo("20");
        assertThat(p.get("montoDefault").decimalValue()).isEqualByComparingTo("80000");

        // El mes nuevo copia el gasto ya en pesos y recuerda los dólares.
        String mes = id(enviar(post("/api/meses"),
                "{\"anio\":2026,\"mes\":8,\"ingresoBase\":0,\"copiarPlantillas\":true}"));
        JsonNode gasto = suscripcion(mes);
        assertThat(gasto.get("monto").decimalValue()).isEqualByComparingTo("80000");
        assertThat(gasto.get("montoUsd").decimalValue()).isEqualByComparingTo("20");

        // Cambia la TRM: el gasto pendiente y la plantilla la siguen.
        enviar(patch("/api/sueldo/" + fuente), "{\"trm\":3600}");
        assertThat(suscripcion(mes).get("monto").decimalValue()).isEqualByComparingTo("72000");
        JsonNode plantilla = json.readTree(mvc.perform(auth(get("/api/plantillas")))
                .andReturn().getResponse().getContentAsString()).get(0);
        assertThat(plantilla.get("montoDefault").decimalValue()).isEqualByComparingTo("72000");
    }

    @Test
    void lo_ya_pagado_no_cambia_con_la_trm() throws Exception {
        enviar(post("/api/plantillas"), """
                {"nombre":"Suscripción","categoria":"HERRAMIENTAS","montoDefault":0,"montoUsd":20}
                """);
        String mes = id(enviar(post("/api/meses"),
                "{\"anio\":2026,\"mes\":8,\"ingresoBase\":0,\"copiarPlantillas\":true}"));
        String gasto = suscripcion(mes).get("id").asText();
        enviar(post("/api/gastos/" + gasto + "/pagar"), "{\"fecha\":\"2026-08-02\"}");

        enviar(patch("/api/sueldo/" + fuente), "{\"trm\":3000}");
        assertThat(suscripcion(mes).get("monto").decimalValue()).isEqualByComparingTo("80000");
    }

    @Test
    void poner_dolares_a_una_plantilla_actualiza_lo_pendiente() throws Exception {
        String plantilla = id(enviar(post("/api/plantillas"), """
                {"nombre":"Suscripción","categoria":"HERRAMIENTAS","montoDefault":90000}
                """));
        String mes = id(enviar(post("/api/meses"),
                "{\"anio\":2026,\"mes\":8,\"ingresoBase\":0,\"copiarPlantillas\":true}"));
        assertThat(suscripcion(mes).get("monto").decimalValue()).isEqualByComparingTo("90000");

        enviar(patch("/api/plantillas/" + plantilla), "{\"montoUsd\":20}");
        assertThat(suscripcion(mes).get("monto").decimalValue()).isEqualByComparingTo("80000");

        // 0 quita la conversión: el monto queda en pesos fijo.
        enviar(patch("/api/plantillas/" + plantilla), "{\"montoUsd\":0,\"montoDefault\":70000}");
        enviar(patch("/api/sueldo/" + fuente), "{\"trm\":3000}");
        JsonNode p = json.readTree(mvc.perform(auth(get("/api/plantillas"))).andReturn()
                .getResponse().getContentAsString()).get(0);
        assertThat(p.has("montoUsd")).isFalse();
        assertThat(p.get("montoDefault").decimalValue()).isEqualByComparingTo("70000");
    }

    // --- ayudantes ---

    private JsonNode suscripcion(String mesId) throws Exception {
        JsonNode lista = json.readTree(mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                .andReturn().getResponse().getContentAsString());
        for (JsonNode g : lista) {
            if (g.get("nombre").asText().equals("Suscripción")) {
                return g;
            }
        }
        throw new AssertionError("No está el gasto");
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

    private String registrar() throws Exception {
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"ana@ejemplo.co\",\"password\":\"" + PASSWORD
                                + "\",\"nombre\":\"Prueba\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }
}
