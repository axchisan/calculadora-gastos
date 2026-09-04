package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Fijar a mano lo que va a costar el transporte del mes.
 *
 * <p>El cálculo por calendario sirve mientras haya una rutina que proyectar. Cuando no la hay
 * —un mes sin empleo, unas vacaciones— lo que se sabe no es cuántos pasajes se van a gastar sino
 * cuánto se va a recargar, y describirlo como días de oficina obliga a inventarse una rutina para
 * que salga la cifra correcta.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Presupuesto de transporte fijado a mano")
class PresupuestoDeTransporteTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;

    private String token;
    private UUID septiembre;

    @BeforeEach
    void preparar() throws Exception {
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();

        token = registrar();
        septiembre = crearMes(2026, 9);
    }

    @Test
    void de_partida_manda_el_calendario() throws Exception {
        mvc.perform(auth(get("/api/meses/" + septiembre + "/transporte/configuracion")))
                .andExpect(jsonPath("$.presupuestoManual").doesNotExist());
    }

    @Test
    void lo_fijado_a_mano_sustituye_al_calculo_en_el_gasto_del_mes() throws Exception {
        double calculado = costoDelGastoDeTransporte();

        fijar("30000");

        // El gasto que llega al presupuesto es el fijado, no el del calendario.
        mvc.perform(auth(get("/api/meses/" + septiembre + "/gastos")))
                .andExpect(jsonPath("$[?(@.origen=='TRANSPORTE')].monto").value(30000.0));

        // Y el calendario sigue calculándose igual por debajo, para poder volver atrás.
        mvc.perform(auth(get("/api/meses/" + septiembre + "/transporte")))
                .andExpect(jsonPath("$.costoTotal").value(calculado));
    }

    @Test
    void con_nulo_vuelve_a_mandar_el_calendario() throws Exception {
        double calculado = costoDelGastoDeTransporte();

        fijar("30000");
        fijar(null);

        mvc.perform(auth(get("/api/meses/" + septiembre + "/transporte/configuracion")))
                .andExpect(jsonPath("$.presupuestoManual").doesNotExist());
        mvc.perform(auth(get("/api/meses/" + septiembre + "/gastos")))
                .andExpect(jsonPath("$[?(@.origen=='TRANSPORTE')].monto").value(calculado));
    }

    /**
     * Lo fijado tiene que aguantar los recálculos: si tocar un día del calendario lo borrase,
     * no serviría de nada.
     */
    @Test
    void sobrevive_a_que_se_toque_el_calendario() throws Exception {
        fijar("30000");

        String dias = mvc.perform(auth(get("/api/meses/" + septiembre + "/transporte")))
                .andReturn().getResponse().getContentAsString();
        String diaId = json.readTree(dias).get("dias").get(0).get("id").asText();

        mvc.perform(auth(patch("/api/meses/" + septiembre + "/transporte/dias/" + diaId + "/tipo"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"tipo\":\"REMOTO\"}"))
                .andExpect(status().isOk());

        mvc.perform(auth(get("/api/meses/" + septiembre + "/gastos")))
                .andExpect(jsonPath("$[?(@.origen=='TRANSPORTE')].monto").value(30000.0));
    }

    @Test
    void un_presupuesto_negativo_se_rechaza() throws Exception {
        mvc.perform(auth(patch("/api/meses/" + septiembre + "/transporte/presupuesto"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"presupuesto\":-1}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void poner_cero_es_valido_y_deja_el_mes_sin_transporte() throws Exception {
        fijar("0");

        mvc.perform(auth(get("/api/meses/" + septiembre + "/gastos")))
                .andExpect(jsonPath("$[?(@.origen=='TRANSPORTE')].monto").value(0.0));
    }

    // --- ayudantes ---

    private void fijar(String presupuesto) throws Exception {
        mvc.perform(auth(patch("/api/meses/" + septiembre + "/transporte/presupuesto"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"presupuesto\":" + (presupuesto == null ? "null" : presupuesto)
                                + "}"))
                .andExpect(status().isOk());
    }

    private double costoDelGastoDeTransporte() throws Exception {
        String respuesta = mvc.perform(auth(get("/api/meses/" + septiembre + "/transporte")))
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("costoTotal").asDouble();
    }

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder peticion) {
        return peticion.header("Authorization", "Bearer " + token);
    }

    private String registrar() throws Exception {
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"duvan@axchisan.com\",\"password\":\"" + PASSWORD
                                + "\",\"nombre\":\"Duvan\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }

    private UUID crearMes(int anio, int mes) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/meses"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"anio\":" + anio + ",\"mes\":" + mes
                                + ",\"ingresoBase\":3000000,\"copiarPlantillas\":false}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(json.readTree(respuesta).get("id").asText());
    }
}
