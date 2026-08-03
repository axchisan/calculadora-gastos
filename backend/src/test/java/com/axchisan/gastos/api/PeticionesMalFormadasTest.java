package com.axchisan.gastos.api;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Una petición que el cliente construye mal debe responderse con un 400, no con un 500.
 *
 * <p>La diferencia importa: un 500 dice «el servidor se rompió» y dispara la alarma, además de
 * quedar registrado con traza completa. Aquí el servidor está perfectamente; lo que llegó mal
 * fue la petición. Antes de estas comprobaciones, un identificador con un carácter de más
 * acababa en la red de seguridad del manejador de errores y devolvía un 500.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Peticiones mal formadas")
class PeticionesMalFormadasTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        refrescos.deleteAll();
        usuarios.deleteAll();

        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"duvan@axchisan.com\",\"password\":\"" + PASSWORD
                                + "\",\"nombre\":\"Duvan\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        token = json.readTree(respuesta).get("accessToken").asText();
    }

    @Test
    void un_identificador_que_no_es_un_uuid_es_culpa_de_la_peticion() throws Exception {
        mvc.perform(auth(get("/api/meses/no-soy-un-uuid/resumen")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("peticion_invalida"));
    }

    /** Un UUID válido pero inexistente sí es un 404: la petición está bien formada. */
    @Test
    void un_identificador_bien_formado_pero_desconocido_es_un_404() throws Exception {
        mvc.perform(auth(get("/api/meses/019fc364-f3a4-7379-b66c-071e8945968d/resumen")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("no_encontrado"));
    }

    @Test
    void un_cuerpo_con_json_roto_no_es_un_error_del_servidor() throws Exception {
        mvc.perform(auth(post("/api/deudas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"acreedor\": "))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("peticion_invalida"));
    }

    @Test
    void un_cuerpo_ausente_tampoco() throws Exception {
        mvc.perform(auth(post("/api/deudas")).contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("peticion_invalida"));
    }

    /**
     * Un número donde se espera un texto, o al revés. Jackson lo rechaza antes de construir el
     * objeto, así que no llega a la validación por campos.
     */
    @Test
    void un_campo_con_el_tipo_cambiado_se_rechaza_con_400() throws Exception {
        mvc.perform(auth(post("/api/deudas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"acreedor\":\"Tarjeta\",\"tipo\":\"TARJETA_CREDITO\","
                                + "\"montoOriginal\":\"muchísimo\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("peticion_invalida"));
    }

    /** Los datos que sí se interpretan pero incumplen las reglas se responden campo a campo. */
    @Test
    void los_datos_invalidos_se_detallan_por_campo() throws Exception {
        mvc.perform(auth(post("/api/deudas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"acreedor\":\"\",\"tipo\":\"TARJETA_CREDITO\","
                                + "\"montoOriginal\":-5000}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("datos_invalidos"))
                .andExpect(jsonPath("$.campos").isMap());
    }

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder peticion) {
        return peticion.header("Authorization", "Bearer " + token);
    }
}
