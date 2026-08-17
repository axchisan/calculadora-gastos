package com.axchisan.gastos.api;

import com.axchisan.gastos.dominio.AliasTarjeta;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.TarjetaRepository;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Cómo se reconoce una tarjeta en las notificaciones de pago del teléfono.
 *
 * <p>Google Wallet publica el apodo que la tarjeta tiene dentro de la billetera y el banco
 * publica los cuatro últimos dígitos. Ninguno de los dos es el nombre que la tarjeta tiene
 * aquí, y de esa traducción depende si la compra salió del dinero de hoy o se va al corte del
 * mes que viene.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Alias de tarjeta")
class AliasDeTarjetaTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private TarjetaRepository tarjetas;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        tarjetas.deleteAll();
        refrescos.deleteAll();
        usuarios.deleteAll();
        token = registrar();
    }

    @Test
    void una_tarjeta_puede_reconocerse_por_apodo_y_por_digitos() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        anadirAlias(nu, "crédito física", "2355");

        mvc.perform(auth(get("/api/tarjetas")))
                .andExpect(jsonPath("$[0].alias.length()").value(1))
                .andExpect(jsonPath("$[0].alias[0].apodo").value("crédito física"))
                .andExpect(jsonPath("$[0].alias[0].ultimos4").value("2355"));
    }

    /**
     * Nu entrega una tarjeta virtual y una física sobre la misma línea de crédito: números
     * distintos, apodos distintos y un solo corte. Las dos tienen que apuntar a la misma
     * tarjeta de la aplicación.
     */
    @Test
    void una_tarjeta_admite_varios_apodos() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        anadirAlias(nu, "crédito física", "2355");
        anadirAlias(nu, "credito digital", "1086");

        mvc.perform(auth(get("/api/tarjetas")))
                .andExpect(jsonPath("$[0].alias.length()").value(2));
    }

    @Test
    void dos_tarjetas_no_pueden_responder_a_lo_mismo() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        String bancolombia = crearTarjeta("Bancolombia", "DEBITO", null, null);

        anadirAlias(nu, "crédito física", "2355");

        // Si las dos respondieran al mismo apodo, la compra acabaría en cualquiera de ellas, y
        // con débito y crédito de por medio eso cambia de qué mes sale el dinero.
        mvc.perform(auth(post("/api/tarjetas/" + bancolombia + "/alias"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"apodo\":\"crédito física\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("peticion_invalida"));

        mvc.perform(auth(post("/api/tarjetas/" + bancolombia + "/alias"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ultimos4\":\"2355\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void un_alias_vacio_no_sirve_para_reconocer_nada() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);

        mvc.perform(auth(post("/api/tarjetas/" + nu + "/alias"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void los_digitos_tienen_que_ser_cuatro() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);

        mvc.perform(auth(post("/api/tarjetas/" + nu + "/alias"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ultimos4\":\"235\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("datos_invalidos"));
    }

    @Test
    void un_alias_se_puede_quitar() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        String aliasId = anadirAlias(nu, "crédito física", "2355");

        mvc.perform(auth(delete("/api/tarjetas/alias/" + aliasId)))
                .andExpect(status().isNoContent());

        mvc.perform(auth(get("/api/tarjetas")))
                .andExpect(jsonPath("$[0].alias.length()").value(0));
    }

    @Test
    void al_borrar_la_tarjeta_se_van_sus_alias() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        anadirAlias(nu, "crédito física", "2355");

        mvc.perform(auth(delete("/api/tarjetas/" + nu)))
                .andExpect(status().isNoContent());

        mvc.perform(auth(get("/api/tarjetas")))
                .andExpect(jsonPath("$.length()").value(0));
    }

    /**
     * El apodo se guarda además normalizado porque el propio usuario escribió «crédito física»
     * con tilde y «credito digital» sin ella. Comparando el texto crudo, uno de los dos no se
     * reconocería nunca.
     */
    @Test
    void el_apodo_se_normaliza_para_poder_compararlo() {
        assertThat(AliasTarjeta.normalizar("Crédito Física")).isEqualTo("credito fisica");
        assertThat(AliasTarjeta.normalizar("  DÉBITO DIGITAL  ")).isEqualTo("debito digital");
        assertThat(AliasTarjeta.normalizar("credito digital")).isEqualTo("credito digital");
        assertThat(AliasTarjeta.normalizar(null)).isNull();
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

    private String crearTarjeta(String nombre, String tipo, Integer corte, Integer pago)
            throws Exception {
        String ciclo = corte == null ? "" : ",\"diaCorte\":" + corte + ",\"diaPago\":" + pago;
        String respuesta = mvc.perform(auth(post("/api/tarjetas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"" + nombre + "\",\"tipo\":\"" + tipo + "\""
                                + ciclo + "}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private String anadirAlias(String tarjetaId, String apodo, String ultimos4) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/tarjetas/" + tarjetaId + "/alias"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"apodo\":\"" + apodo + "\",\"ultimos4\":\"" + ultimos4 + "\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }
}
