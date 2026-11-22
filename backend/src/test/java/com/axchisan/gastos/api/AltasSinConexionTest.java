package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
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
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.UUID;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Altas con el identificador que genera la app.
 *
 * <p>Lo que se apunta sin conexión se crea primero en el teléfono con un identificador propio y
 * se envía al volver la red. Si la respuesta de ese envío se pierde (la red se corta justo
 * después), la app lo reenvía. Estas pruebas aseguran que el reenvío no duplica nada: un gasto
 * contado dos veces descuadraría el mes sin que nadie supiera por qué.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Altas desde la cola sin conexión")
class AltasSinConexionTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private CompraRepository compras;
    @Autowired private TarjetaRepository tarjetas;

    private String token;
    private UUID agosto;

    @BeforeEach
    void preparar() throws Exception {
        compras.deleteAll();
        tarjetas.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();

        token = registrar("ana@ejemplo.co");
        agosto = crearMes(token, 2026, 8);
    }

    @Test
    void una_compra_reenviada_con_el_mismo_identificador_no_se_duplica() throws Exception {
        UUID id = UUID.randomUUID();
        String cuerpo = "{\"id\":\"" + id + "\",\"descripcion\":\"Pan\",\"monto\":4000,"
                + "\"categoria\":\"ALIMENTACION\",\"fecha\":\"2026-08-05\",\"medio\":\"EFECTIVO\"}";

        enviar(token, post("/api/meses/" + agosto + "/compras"), cuerpo)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(id.toString()));
        enviar(token, post("/api/meses/" + agosto + "/compras"), cuerpo)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(id.toString()));

        mvc.perform(auth(token, get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.compras", hasSize(1)));
        mvc.perform(auth(token, get("/api/meses/" + agosto + "/resumen")))
                .andExpect(jsonPath("$.comprasInmediatas").value(4000));
    }

    @Test
    void un_gasto_reenviado_no_se_duplica() throws Exception {
        UUID id = UUID.randomUUID();
        String cuerpo = "{\"id\":\"" + id + "\",\"nombre\":\"Wifi\",\"categoria\":\"SERVICIOS\","
                + "\"monto\":40000}";

        enviar(token, post("/api/meses/" + agosto + "/gastos"), cuerpo)
                .andExpect(status().isCreated());
        enviar(token, post("/api/meses/" + agosto + "/gastos"), cuerpo)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(id.toString()));

        mvc.perform(auth(token, get("/api/meses/" + agosto + "/gastos")))
                .andExpect(jsonPath("$[?(@.nombre == 'Wifi')]", hasSize(1)));
    }

    @Test
    void un_ingreso_reenviado_no_se_duplica() throws Exception {
        UUID id = UUID.randomUUID();
        String cuerpo = "{\"id\":\"" + id + "\",\"concepto\":\"Trabajo extra\",\"monto\":70000,"
                + "\"fecha\":\"2026-08-11\",\"recibido\":true}";

        enviar(token, post("/api/meses/" + agosto + "/ingresos"), cuerpo)
                .andExpect(status().isCreated());
        enviar(token, post("/api/meses/" + agosto + "/ingresos"), cuerpo)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(id.toString()));

        mvc.perform(auth(token, get("/api/meses/" + agosto + "/ingresos")))
                .andExpect(jsonPath("$", hasSize(1)));
        // El sueldo son 3.000.000 y el ingreso cuenta una sola vez.
        mvc.perform(auth(token, get("/api/meses/" + agosto + "/resumen")))
                .andExpect(jsonPath("$.disponibleHoy").value(3070000));
    }

    @Test
    void sin_identificador_todo_sigue_como_antes() throws Exception {
        String cuerpo = "{\"descripcion\":\"Pan\",\"monto\":4000,\"categoria\":\"ALIMENTACION\","
                + "\"fecha\":\"2026-08-05\"}";
        enviar(token, post("/api/meses/" + agosto + "/compras"), cuerpo)
                .andExpect(status().isCreated());
        enviar(token, post("/api/meses/" + agosto + "/compras"), cuerpo)
                .andExpect(status().isCreated());

        mvc.perform(auth(token, get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.compras", hasSize(2)));
    }

    @Test
    void el_identificador_de_otro_usuario_se_rechaza() throws Exception {
        UUID id = UUID.randomUUID();
        String cuerpo = "{\"id\":\"" + id + "\",\"descripcion\":\"Pan\",\"monto\":4000,"
                + "\"categoria\":\"ALIMENTACION\",\"fecha\":\"2026-08-05\"}";
        enviar(token, post("/api/meses/" + agosto + "/compras"), cuerpo)
                .andExpect(status().isCreated());

        String otro = registrar("beto@ejemplo.co");
        UUID agostoDeBeto = crearMes(otro, 2026, 8);
        enviar(otro, post("/api/meses/" + agostoDeBeto + "/compras"), cuerpo)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("identificador_en_uso"));
    }

    private ResultActions enviar(String quien, MockHttpServletRequestBuilder peticion,
                                 String cuerpo) throws Exception {
        return mvc.perform(auth(quien, peticion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(cuerpo));
    }

    private MockHttpServletRequestBuilder auth(String quien,
                                               MockHttpServletRequestBuilder peticion) {
        return peticion.header("Authorization", "Bearer " + quien);
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

    private UUID crearMes(String quien, int anio, int mes) throws Exception {
        String respuesta = mvc.perform(auth(quien, post("/api/meses"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"anio\":" + anio + ",\"mes\":" + mes
                                + ",\"ingresoBase\":3000000,\"copiarPlantillas\":false}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(json.readTree(respuesta).get("id").asText());
    }
}
