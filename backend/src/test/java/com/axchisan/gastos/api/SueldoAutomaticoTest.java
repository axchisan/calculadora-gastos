package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
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

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * El sueldo base de los meses que vienen de un sueldo en dólares sigue a la TRM, salvo que se
 * haya fijado a mano o ya haya llegado el pago. Cifras inventadas.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Sueldo base automático")
class SueldoAutomaticoTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private FuenteIngresoRepository fuentes;

    private String token;
    private String fuenteId;

    @BeforeEach
    void preparar() throws Exception {
        fuentes.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();
        fuenteId = json.readTree(enviar(post("/api/sueldo"), """
                {"nombre":"Empresa","montoMensual":1000,"fechaInicio":"2026-01-01",
                 "medio":"TRANSFERENCIA","trm":4000}
                """).getResponse().getContentAsString()).get("id").asText();
    }

    @Test
    void los_meses_llevados_al_presupuesto_siguen_a_la_trm() throws Exception {
        JsonNode aplicados = json.readTree(enviar(
                post("/api/sueldo/" + fuenteId + "/llevar-al-presupuesto?pagos=3"), "")
                .getResponse().getContentAsString());
        assertThat(aplicados).hasSize(3);
        String primero = aplicados.get(0).get("periodo").asText();
        BigDecimal antes = aplicados.get(0).get("ingresoBase").decimalValue();

        JsonNode mes = mes(primero);
        assertThat(mes.get("sueldoAutomatico").asBoolean()).isTrue();

        // Sube el dólar: el sueldo de los meses marcados se recalcula solo.
        enviar(patch("/api/sueldo/" + fuenteId), "{\"trm\":4500}");
        BigDecimal despues = mes(primero).get("ingresoBase").decimalValue();
        assertThat(despues).isGreaterThan(antes);
        assertThat(despues.divide(antes, 2, java.math.RoundingMode.HALF_UP))
                .isEqualByComparingTo("1.13");
    }

    @Test
    void lo_fijado_a_mano_no_se_pisa() throws Exception {
        JsonNode aplicados = json.readTree(enviar(
                post("/api/sueldo/" + fuenteId + "/llevar-al-presupuesto?pagos=2"), "")
                .getResponse().getContentAsString());
        String primero = aplicados.get(0).get("periodo").asText();
        String segundo = aplicados.get(1).get("periodo").asText();
        String idPrimero = mes(primero).get("id").asText();

        enviar(patch("/api/meses/" + idPrimero), "{\"ingresoBase\":3000000}");
        assertThat(mes(primero).get("sueldoAutomatico").asBoolean()).isFalse();

        enviar(patch("/api/sueldo/" + fuenteId), "{\"trm\":5000}");
        assertThat(mes(primero).get("ingresoBase").decimalValue())
                .isEqualByComparingTo("3000000");
        assertThat(mes(segundo).get("sueldoAutomatico").asBoolean()).isTrue();
        assertThat(mes(segundo).get("ingresoBase").decimalValue())
                .isNotEqualByComparingTo(aplicados.get(1).get("ingresoBase").decimalValue());
    }

    @Test
    void un_mes_creado_a_mano_no_es_automatico() throws Exception {
        enviar(post("/api/meses"),
                "{\"anio\":2030,\"mes\":5,\"ingresoBase\":100,\"copiarPlantillas\":false}");
        assertThat(mes("2030-05").get("sueldoAutomatico").asBoolean()).isFalse();
    }

    // --- ayudas ---

    private JsonNode mes(String periodo) throws Exception {
        String[] p = periodo.split("-");
        return json.readTree(mvc.perform(auth(get("/api/meses/periodo/" + Integer.parseInt(p[0])
                        + "/" + Integer.parseInt(p[1]))))
                .andReturn().getResponse().getContentAsString());
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
