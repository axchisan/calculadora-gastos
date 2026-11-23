package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.ClaveIngestaRepository;
import com.axchisan.gastos.repositorio.MovimientoDetectadoRepository;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.ReglaDeteccionRepository;
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

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Avisos que llegan solos con una clave de ingesta. Textos y cifras inventados. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Ingesta de avisos")
class IngestaTest {

    private static final String PASSWORD = "unaClaveSegura123";
    private static final String SMS = "Bancolombia: Compraste $12.500,00 en TIENDA LA ESQUINA con "
            + "tu T.Deb *4321, el 14/08/2026 a las 18:05.";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MovimientoDetectadoRepository detectados;
    @Autowired private ReglaDeteccionRepository reglas;
    @Autowired private ClaveIngestaRepository claves;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        detectados.deleteAll();
        reglas.deleteAll();
        claves.deleteAll();
        refrescos.deleteAll();
        usuarios.deleteAll();
        token = registrar("ana@ejemplo.co");
    }

    @Test
    void con_la_clave_los_avisos_llegan_a_la_bandeja_sin_sesion() throws Exception {
        String clave = crearClave("Teléfono");
        assertThat(clave).startsWith("gk_");

        JsonNode r = conClave(clave, lote(
                aviso("SMS", SMS),
                aviso("SMS", SMS),
                aviso("SMS", "Bancolombia: 123456 es el codigo para activar tu billetera."),
                aviso("CORREO", "Bancolombia: algo nuevo de $5.000")), 200);
        assertThat(r.get("nuevos").asInt()).isEqualTo(1);
        assertThat(r.get("repetidos").asInt()).isEqualTo(1);
        assertThat(r.get("ignorados").asInt()).isEqualTo(1);
        assertThat(r.get("noReconocidos").asInt()).isEqualTo(1);

        JsonNode pendientes = json.readTree(mvc.perform(get("/api/detectados")
                        .header("Authorization", "Bearer " + token))
                .andReturn().getResponse().getContentAsString());
        assertThat(pendientes).hasSize(1);

        // La clave registra cuándo se usó por última vez.
        JsonNode lista = json.readTree(mvc.perform(get("/api/ingesta/claves")
                .header("Authorization", "Bearer " + token)).andReturn().getResponse()
                .getContentAsString());
        assertThat(lista).hasSize(1);
        assertThat(lista.get(0).get("nombre").asText()).isEqualTo("Teléfono");
        assertThat(lista.get(0).has("usada")).isTrue();
        assertThat(lista.get(0).has("clave")).isFalse();
    }

    @Test
    void sin_clave_o_con_una_revocada_no_entra_nada() throws Exception {
        conClave(null, lote(aviso("SMS", SMS)), 401);
        conClave("gk_inventada", lote(aviso("SMS", SMS)), 401);

        String clave = crearClave("Gmail");
        String id = json.readTree(mvc.perform(get("/api/ingesta/claves")
                .header("Authorization", "Bearer " + token)).andReturn().getResponse()
                .getContentAsString()).get(0).get("id").asText();
        mvc.perform(delete("/api/ingesta/claves/" + id).header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
        conClave(clave, lote(aviso("SMS", SMS)), 401);
        assertThat(detectados.count()).isZero();
    }

    @Test
    void la_clave_no_sirve_para_nada_mas() throws Exception {
        String clave = crearClave("Teléfono");
        mvc.perform(get("/api/detectados").header("X-Clave-Ingesta", clave))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/detectados").header("Authorization", "Bearer " + clave))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void cada_clave_es_de_su_usuario() throws Exception {
        String deAna = crearClave("Teléfono");
        String tokenAna = token;
        token = registrar("otro@ejemplo.co");
        conClave(deAna, lote(aviso("SMS", SMS)), 200);
        JsonNode delOtro = json.readTree(mvc.perform(get("/api/detectados")
                .header("Authorization", "Bearer " + token)).andReturn().getResponse()
                .getContentAsString());
        assertThat(delOtro).isEmpty();
        JsonNode deAnaBandeja = json.readTree(mvc.perform(get("/api/detectados")
                .header("Authorization", "Bearer " + tokenAna)).andReturn().getResponse()
                .getContentAsString());
        assertThat(deAnaBandeja).hasSize(1);
    }

    @Test
    void el_historial_se_manda_por_lotes_con_la_sesion() throws Exception {
        List<Map<String, String>> muchos = new ArrayList<>();
        for (int i = 1; i <= 20; i++) {
            muchos.add(aviso("SMS", SMS.replace("14/08/2026", String.format("%02d/07/2026", i))));
        }
        MvcResult r = mvc.perform(post("/api/detectados/avisos/lote")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("avisos", muchos))))
                .andExpect(status().isOk()).andReturn();
        assertThat(json.readTree(r.getResponse().getContentAsString()).get("nuevos").asInt())
                .isEqualTo(20);

        List<Map<String, String>> demasiados = new ArrayList<>();
        for (int i = 0; i < 201; i++) {
            demasiados.add(aviso("SMS", SMS));
        }
        mvc.perform(post("/api/detectados/avisos/lote")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("avisos", demasiados))))
                .andExpect(status().isBadRequest());
    }

    // --- ayudantes ---

    private static Map<String, String> aviso(String origen, String texto) {
        return Map.of("origen", origen, "texto", texto);
    }

    @SafeVarargs
    private static Map<String, Object> lote(Map<String, String>... avisos) {
        return Map.of("avisos", List.of(avisos));
    }

    private JsonNode conClave(String clave, Map<String, Object> cuerpo, int esperado)
            throws Exception {
        var peticion = post("/api/ingesta/avisos").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(cuerpo));
        if (clave != null) {
            peticion.header("X-Clave-Ingesta", clave);
        }
        MvcResult r = mvc.perform(peticion).andReturn();
        assertThat(r.getResponse().getStatus()).as(r.getResponse().getContentAsString())
                .isEqualTo(esperado);
        return json.readTree(r.getResponse().getContentAsString());
    }

    private String crearClave(String nombre) throws Exception {
        MvcResult r = mvc.perform(post("/api/ingesta/claves")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"" + nombre + "\"}"))
                .andExpect(status().isCreated()).andReturn();
        return json.readTree(r.getResponse().getContentAsString()).get("clave").asText();
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
