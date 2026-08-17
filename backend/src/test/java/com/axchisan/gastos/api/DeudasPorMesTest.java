package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.DeudaRepository;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Qué deudas corresponden a cada mes.
 *
 * <p>Una deuda no pertenece a un mes: se contrae un día y se arrastra hasta saldarla. Pero
 * listarlas todas siempre hacía que las de agosto, ya pagadas, siguieran apareciendo en
 * septiembre como si aún se debieran, mezcladas con las de verdad.
 *
 * <p>El criterio es que una deuda importa en un mes si ya existía al terminarlo y, además, o
 * bien seguía debiéndose a esas alturas, o bien se abonó algo durante ese mes.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Deudas por mes")
class DeudasPorMesTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private DeudaRepository deudas;

    private String token;
    private UUID agosto;

    @BeforeEach
    void preparar() throws Exception {
        refrescos.deleteAll();
        deudas.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();

        token = registrar();
        agosto = crearMes(2026, 8);
        crearMes(2026, 9);
    }

    /** El caso concreto que había que arreglar. */
    @Test
    void una_deuda_saldada_en_agosto_no_aparece_en_septiembre() throws Exception {
        String lexy = crearDeuda("Lexy", 300000, "2026-08-03");
        abonar(lexy, 300000, "2026-08-10");

        mvc.perform(auth(get("/api/deudas?periodo=2026-08")))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].acreedor").value("Lexy"));

        mvc.perform(auth(get("/api/deudas?periodo=2026-09")))
                .andExpect(jsonPath("$.length()").value(0));
    }

    /**
     * Lo contrario también tiene que cumplirse: una deuda que sigue debiéndose acompaña al
     * usuario mes tras mes hasta que la salde.
     */
    @Test
    void una_deuda_sin_saldar_sigue_apareciendo_los_meses_siguientes() throws Exception {
        crearDeuda("Mama", 400000, "2026-08-03");

        mvc.perform(auth(get("/api/deudas?periodo=2026-08")))
                .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(auth(get("/api/deudas?periodo=2026-09")))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].saldo").value(400000));
        mvc.perform(auth(get("/api/deudas?periodo=2027-03")))
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void una_deuda_no_aparece_en_los_meses_anteriores_a_contraerla() throws Exception {
        crearDeuda("Tarjeta", 500000, "2026-09-05");

        mvc.perform(auth(get("/api/deudas?periodo=2026-08")))
                .andExpect(jsonPath("$.length()").value(0));
        mvc.perform(auth(get("/api/deudas?periodo=2026-09")))
                .andExpect(jsonPath("$.length()").value(1));
    }

    /**
     * Al mirar un mes pasado interesa el saldo de entonces, no el de hoy: en agosto todavía se
     * debían los 300.000, aunque hoy la deuda esté en cero.
     */
    @Test
    void cada_mes_muestra_el_saldo_que_la_deuda_tenia_entonces() throws Exception {
        String deuda = crearDeuda("Monet", 300000, "2026-08-03");
        abonar(deuda, 100000, "2026-08-20");
        abonar(deuda, 200000, "2026-09-05");

        // Al cerrar agosto quedaban 200.000 por pagar.
        mvc.perform(auth(get("/api/deudas?periodo=2026-08")))
                .andExpect(jsonPath("$[0].saldo").value(200000))
                .andExpect(jsonPath("$[0].porcentajePagado").value(33.33))
                .andExpect(jsonPath("$[0].activa").value(true));

        // En septiembre se terminó de pagar.
        mvc.perform(auth(get("/api/deudas?periodo=2026-09")))
                .andExpect(jsonPath("$[0].saldo").value(0))
                .andExpect(jsonPath("$[0].activa").value(false));

        // Y en octubre ya no pinta nada.
        mvc.perform(auth(get("/api/deudas?periodo=2026-10")))
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void sin_periodo_se_siguen_listando_todas() throws Exception {
        String lexy = crearDeuda("Lexy", 300000, "2026-08-03");
        abonar(lexy, 300000, "2026-08-10");
        crearDeuda("Mama", 400000, "2026-08-03");

        mvc.perform(auth(get("/api/deudas")))
                .andExpect(jsonPath("$.length()").value(2));
        mvc.perform(auth(get("/api/deudas?soloActivas=true")))
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void un_periodo_mal_escrito_es_culpa_de_la_peticion() throws Exception {
        mvc.perform(auth(get("/api/deudas?periodo=agosto")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("peticion_invalida"));
    }

    // --- utilidades ---

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

    private String crearDeuda(String acreedor, int monto, String fechaInicio) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/deudas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"acreedor\":\"" + acreedor + "\",\"tipo\":\"AMIGO\","
                                + "\"montoOriginal\":" + monto
                                + ",\"fechaInicio\":\"" + fechaInicio + "\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private void abonar(String deudaId, int monto, String fecha) throws Exception {
        mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"monto\":" + monto + ",\"fecha\":\"" + fecha
                                + "\",\"mesId\":\"" + agosto + "\"}"))
                .andExpect(status().isCreated());
    }
}
