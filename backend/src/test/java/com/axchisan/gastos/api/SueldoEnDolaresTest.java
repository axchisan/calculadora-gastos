package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Sueldo en dólares: TRM y pagos recibidos")
class SueldoEnDolaresTest {

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

        String creada = mvc.perform(auth(post("/api/sueldo"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nombre":"Migozz","montoMensual":600,"fechaInicio":"2026-10-23",
                                 "medio":"TRANSFERENCIA","trm":3301.91}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.trmAutomatica").value(false))
                .andReturn().getResponse().getContentAsString();
        fuenteId = json.readTree(creada).get("id").asText();
    }

    @Test
    void sin_trm_y_sin_poder_consultarla_se_pide_a_mano() throws Exception {
        mvc.perform(auth(post("/api/sueldo"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nombre":"Otro","montoMensual":100,"fechaInicio":"2026-10-01"}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void registrar_lo_que_llego_fija_el_sueldo_del_mes_y_la_tasa_efectiva() throws Exception {
        // Llegan 2.540.000 por los 774,19 USD del primer pago.
        mvc.perform(auth(post("/api/sueldo/" + fuenteId + "/pagos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"mesDePago":"2026-12","montoPesos":2540000,"fecha":"2026-12-04"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.montoOriginal").value(774.19))
                .andExpect(jsonPath("$.tasaEfectiva").value(3280.85));

        mvc.perform(auth(get("/api/meses/periodo/2026/12")))
                .andExpect(jsonPath("$.ingresoBase").value(2540000.0));

        mvc.perform(auth(get("/api/sueldo")))
                .andExpect(jsonPath("$[0].recibidos[0].montoPesos").value(2540000.0));
    }

    @Test
    void llevar_al_presupuesto_no_pisa_un_pago_ya_recibido() throws Exception {
        mvc.perform(auth(post("/api/sueldo/" + fuenteId + "/pagos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"mesDePago":"2026-12","montoPesos":2540000,"fecha":"2026-12-04"}
                                """))
                .andExpect(status().isCreated());

        mvc.perform(auth(post("/api/sueldo/" + fuenteId
                        + "/llevar-al-presupuesto?desde=2026-12&pagos=2")))
                .andExpect(status().isOk());

        mvc.perform(auth(get("/api/meses/periodo/2026/12")))
                .andExpect(jsonPath("$.ingresoBase").value(2540000.0));
        // Enero sí se toma de la proyección: 600 × 3.301,91.
        mvc.perform(auth(get("/api/meses/periodo/2027/1")))
                .andExpect(jsonPath("$.ingresoBase").value(1981146.0));
    }

    @Test
    void escribir_una_trm_a_mano_la_fija() throws Exception {
        mvc.perform(auth(patch("/api/sueldo/" + fuenteId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trmAutomatica\":true}"))
                .andExpect(jsonPath("$.trmAutomatica").value(true));

        mvc.perform(auth(patch("/api/sueldo/" + fuenteId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trm\":3250}"))
                .andExpect(jsonPath("$.trmAutomatica").value(false))
                .andExpect(jsonPath("$.trm").value(3250.0));
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
}
