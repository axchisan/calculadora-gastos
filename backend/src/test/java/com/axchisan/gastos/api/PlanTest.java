package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MetaAhorroRepository;
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

/**
 * «Mi plan». Cifras inventadas. Hoy es el 20 de agosto de 2026: el mes en curso es agosto (28
 * jul – 27 ago) y quedan 8 de sus 31 días.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Mi plan")
class PlanTest {

    private static final String PASSWORD = "unaClaveSegura123";
    private static final String HOY = "2026-08-20";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private CompraRepository compras;
    @Autowired private DeudaRepository deudas;
    @Autowired private MetaAhorroRepository metas;
    @Autowired private PlantillaGastoRepository plantillas;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        compras.deleteAll();
        deudas.deleteAll();
        metas.deleteAll();
        plantillas.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();

        // El día a día de los tres meses cerrados: la mediana es 400.000 (junio fue raro).
        compra(crearMes(2026, 5, 0), "2026-05-10", 300000);
        compra(crearMes(2026, 6, 0), "2026-06-10", 900000);
        compra(crearMes(2026, 7, 0), "2026-07-10", 400000);

        crearMes(2026, 8, 1000000);
        String septiembre = crearMes(2026, 9, 2000000);
        enviar(post("/api/meses/" + septiembre + "/gastos"),
                "{\"nombre\":\"Internet\",\"categoria\":\"SERVICIOS\",\"monto\":200000}");
        crearMes(2026, 10, 2000000);
        crearMes(2026, 11, 2000000);
        // Diciembre no existe: usa las plantillas y, sin fuente de ingreso, no entra nada.
        enviar(post("/api/plantillas"),
                "{\"nombre\":\"Celular\",\"categoria\":\"SERVICIOS\",\"montoDefault\":150000}");
        // 700.000 a 300.000 al mes desde el 4 de septiembre: 300, 300 y 100.
        enviar(post("/api/deudas"), """
                {"acreedor":"Tarjeta de ejemplo","tipo":"TARJETA_CREDITO","montoOriginal":700000,
                 "fechaInicio":"2026-08-01","cuotaSugerida":300000,"fechaLimite":"2026-09-04"}
                """);
    }

    @Test
    void cuenta_lo_que_sobra_cada_mes_despues_de_pagar_todo() throws Exception {
        JsonNode plan = plan(5);
        assertThat(plan.get("gastoDiarioEstimado").decimalValue()).isEqualByComparingTo("400000");
        assertThat(plan.get("gastoDiarioPropio").asBoolean()).isFalse();

        JsonNode m = plan.get("meses");
        assertThat(m).hasSize(5);
        assertThat(m.get(0).get("periodo").asText()).isEqualTo("2026-08");
        assertThat(m.get(0).get("actual").asBoolean()).isTrue();
        // Del día a día de agosto solo faltan 8 de 31 días.
        assertThat(m.get(0).get("diario").decimalValue()).isEqualByComparingTo("103226");

        // Septiembre: 2.000.000 − 200.000 de internet − 300.000 de la tarjeta − 400.000.
        JsonNode sep = m.get(1);
        assertThat(sep.get("ingreso").decimalValue()).isEqualByComparingTo("2000000");
        assertThat(sep.get("fijos").decimalValue()).isEqualByComparingTo("200000");
        assertThat(sep.get("totalPagos").decimalValue()).isEqualByComparingTo("300000");
        assertThat(sep.get("pagos").get(0).get("nombre").asText()).isEqualTo("Tarjeta de ejemplo");
        assertThat(sep.get("pagos").get(0).get("fecha").asText()).isEqualTo("2026-09-04");
        assertThat(sep.get("sobra").decimalValue()).isEqualByComparingTo("1100000");
        assertThat(m.get(2).get("sobra").decimalValue()).isEqualByComparingTo("1300000");
        // En noviembre la tarjeta termina con 100.000.
        assertThat(m.get(3).get("totalPagos").decimalValue()).isEqualByComparingTo("100000");
        assertThat(m.get(3).get("sobra").decimalValue()).isEqualByComparingTo("1500000");
        // Diciembre: sin sueldo proyectado y con la plantilla del celular, no alcanza.
        assertThat(m.get(4).get("fijos").decimalValue()).isEqualByComparingTo("150000");
        assertThat(m.get(4).get("sobra").decimalValue()).isEqualByComparingTo("-550000");
    }

    @Test
    void dice_cuando_se_alcanza_una_meta() throws Exception {
        enviar(post("/api/ahorro/metas"), """
                {"nombre":"Teléfono nuevo","tipoAsignacion":"MONTO_FIJO","valor":1000000,
                 "metaMonto":2300000}
                """);
        JsonNode meta = plan(5).get("metas").get(0);
        assertThat(meta.get("nombre").asText()).isEqualTo("Teléfono nuevo");
        assertThat(meta.get("faltan").decimalValue()).isEqualByComparingTo("2300000");
        assertThat(meta.get("aporteMensual").decimalValue()).isEqualByComparingTo("1000000");
        // Apartando 1.000.000: septiembre, octubre y lo que falta en noviembre.
        assertThat(meta.get("alcanzaEn").asText()).isEqualTo("2026-11");
        assertThat(meta.get("aportes").get(2).get("monto").decimalValue())
                .isEqualByComparingTo("300000");
        // Apartando todo lo que sobra (1.100.000 + 1.300.000) bastaría con octubre.
        assertThat(meta.get("alcanzaEnConTodo").asText()).isEqualTo("2026-10");
    }

    @Test
    void una_meta_que_no_alcanza_lo_dice() throws Exception {
        enviar(post("/api/ahorro/metas"), """
                {"nombre":"Viaje","tipoAsignacion":"PORCENTAJE_SOBRANTE","valor":10,
                 "metaMonto":90000000}
                """);
        JsonNode meta = plan(5).get("metas").get(0);
        // El 10 % de lo que sobra: 110.000 en septiembre.
        assertThat(meta.get("aporteMensual").decimalValue()).isEqualByComparingTo("110000");
        assertThat(meta.has("alcanzaEn")).isFalse();
        assertThat(meta.has("alcanzaEnConTodo")).isFalse();
    }

    @Test
    void el_dia_a_dia_se_puede_poner_a_mano() throws Exception {
        JsonNode plan = json.readTree(enviar(patch("/api/plan/ajustes"),
                "{\"gastoDiario\":300000}").getResponse().getContentAsString());
        assertThat(plan.get("gastoDiario").decimalValue()).isEqualByComparingTo("300000");
        assertThat(plan.get("gastoDiarioPropio").asBoolean()).isTrue();
        assertThat(plan(3).get("meses").get(1).get("sobra").decimalValue())
                .isEqualByComparingTo("1200000");

        enviar(patch("/api/plan/ajustes"), "{\"gastoDiario\":null}");
        assertThat(plan(3).get("gastoDiario").decimalValue()).isEqualByComparingTo("400000");

        mvc.perform(auth(patch("/api/plan/ajustes")).contentType(MediaType.APPLICATION_JSON)
                .content("{\"gastoDiario\":-5}")).andExpect(status().isBadRequest());
    }

    // --- ayudantes ---

    private JsonNode plan(int cuantos) throws Exception {
        return json.readTree(mvc.perform(auth(get("/api/plan?meses=" + cuantos + "&fecha=" + HOY)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private void compra(String mesId, String fecha, int monto) throws Exception {
        enviar(post("/api/meses/" + mesId + "/compras"), "{\"descripcion\":\"Mercado\",\"monto\":"
                + monto + ",\"categoria\":\"ALIMENTACION\",\"fecha\":\"" + fecha
                + "\",\"medio\":\"EFECTIVO\"}");
    }

    private String crearMes(int anio, int mes, int sueldo) throws Exception {
        return id(enviar(post("/api/meses"), "{\"anio\":" + anio + ",\"mes\":" + mes
                + ",\"ingresoBase\":" + sueldo + ",\"copiarPlantillas\":false}"));
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
