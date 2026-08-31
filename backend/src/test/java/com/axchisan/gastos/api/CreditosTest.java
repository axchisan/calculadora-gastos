package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CreditoRepository;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Créditos con cuadro de amortización.
 *
 * <p>Las cifras salen del plan real de Bancamía: 4.371.000 al 76% efectivo anual a 18 cuotas,
 * con un saldo de capital de 4.226.306,32 al empezar el cuadro. Se usan tres cuotas del plan en
 * vez de las dieciocho porque lo que se comprueba aquí es la mecánica, no la aritmética —de eso
 * se ocupa {@code AmortizacionTest} contra el plan completo.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Créditos")
class CreditosTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private CreditoRepository creditos;
    @Autowired private MesPresupuestalRepository meses;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        creditos.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();
    }

    @Test
    void guarda_el_cuadro_tal_y_como_lo_imprime_el_banco() throws Exception {
        String id = crearCredito();

        mvc.perform(auth(get("/api/creditos/" + id + "/cuotas")))
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].numero").value(1))
                .andExpect(jsonPath("$[0].pagada").value(true))
                .andExpect(jsonPath("$[1].saldoCapital").value(4226306.32))
                .andExpect(jsonPath("$[1].capital").value(166085.74))
                .andExpect(jsonPath("$[1].interes").value(203863.36))
                .andExpect(jsonPath("$[1].valorCuota").value(404304.00))
                // Los cargos son todo lo que no es capital ni interés: Mipyme más seguro.
                .andExpect(jsonPath("$[1].cargos").value(34355.10));
    }

    @Test
    void el_estado_separa_lo_pagado_de_lo_que_queda() throws Exception {
        String id = crearCredito();

        mvc.perform(auth(get("/api/creditos/" + id)))
                .andExpect(jsonPath("$.entidad").value("Bancamía"))
                .andExpect(jsonPath("$.cuotasTotales").value(3))
                .andExpect(jsonPath("$.cuotasPagadas").value(1))
                // El saldo lo declara la primera cuota sin pagar: viene del banco, no de una resta.
                .andExpect(jsonPath("$.saldo").value(4226306.32))
                .andExpect(jsonPath("$.totalPendiente").value(808539.00))
                .andExpect(jsonPath("$.proximaCuota.numero").value(2));
    }

    /**
     * La cifra que no aparece en ningún extracto: lo que el crédito cuesta por encima de lo
     * prestado. Al 76% anual es más de la mitad otra vez.
     */
    @Test
    void enseña_cuanto_cuesta_el_credito_por_encima_de_lo_prestado() throws Exception {
        String id = crearCredito();

        mvc.perform(auth(get("/api/creditos/" + id)))
                .andExpect(jsonPath("$.costeTotal").value(399715.28));
    }

    @Test
    void pagar_una_cuota_mueve_el_saldo_a_la_siguiente() throws Exception {
        String id = crearCredito();
        String cuota2 = idDeLaCuota(id, 1);

        mvc.perform(auth(put("/api/creditos/cuotas/" + cuota2))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"pagada\":true,\"fecha\":\"2026-10-02\"}"))
                .andExpect(jsonPath("$.pagada").value(true));

        mvc.perform(auth(get("/api/creditos/" + id)))
                .andExpect(jsonPath("$.cuotasPagadas").value(2))
                .andExpect(jsonPath("$.saldo").value(4060220.58))
                .andExpect(jsonPath("$.proximaCuota.numero").value(3));
    }

    // --- lo que justifica el módulo ---

    @Test
    void simula_un_abono_que_acorta_el_plazo() throws Exception {
        String id = crearCredito();

        // Con solo dos cuotas por delante la cuota es enorme, así que hace falta un abono
        // grande para eliminar una. En el plan completo, a dieciocho cuotas, mucho menos basta.
        mvc.perform(auth(get("/api/creditos/" + id
                        + "/simulacion?abono=2500000&modo=REDUCIR_PLAZO")))
                .andExpect(jsonPath("$.abono").value(2500000))
                .andExpect(jsonPath("$.cuotasAntes").value(2))
                .andExpect(jsonPath("$.cuotasDespues").value(1))
                .andExpect(jsonPath("$.cuotasAhorradas").value(1));
    }

    /** Lo que de verdad se gana adelantando: intereses que ese capital ya no genera. */
    @Test
    void adelantar_ahorra_intereses() throws Exception {
        String id = crearCredito();

        mvc.perform(auth(get("/api/creditos/" + id
                        + "/simulacion?abono=500000&modo=REDUCIR_PLAZO")))
                .andExpect(jsonPath("$.ahorroInteres",
                        org.hamcrest.Matchers.greaterThan(0.0)))
                // El interés que queda por pagar baja respecto de no hacer nada.
                .andExpect(jsonPath("$.interesDespues",
                        org.hamcrest.Matchers.lessThan(400000.0)));
    }

    @Test
    void simula_un_abono_que_baja_la_cuota() throws Exception {
        String id = crearCredito();

        mvc.perform(auth(get("/api/creditos/" + id
                        + "/simulacion?abono=500000&modo=REDUCIR_CUOTA")))
                // Se mantienen las cuotas y baja lo que se paga cada mes.
                .andExpect(jsonPath("$.cuotasDespues").value(2))
                .andExpect(jsonPath("$.cuotasAhorradas").value(0))
                .andExpect(jsonPath("$.cuotaDespues",
                        org.hamcrest.Matchers.lessThan(2300000.0)));
    }

    @Test
    void un_abono_mayor_que_el_saldo_se_rechaza() throws Exception {
        String id = crearCredito();

        mvc.perform(auth(get("/api/creditos/" + id + "/simulacion?abono=99999999")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.mensaje").value(
                        org.hamcrest.Matchers.containsString("supera el saldo")));
    }

    @Test
    void un_abono_de_cero_no_se_simula() throws Exception {
        String id = crearCredito();

        mvc.perform(auth(get("/api/creditos/" + id + "/simulacion?abono=0")))
                .andExpect(status().isBadRequest());
    }

    /** Sin cuadro no hay crédito que valga: es lo único que permite calcular algo. */
    @Test
    void un_credito_sin_cuadro_no_se_admite() throws Exception {
        mvc.perform(auth(post("/api/creditos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"entidad\":\"X\",\"montoOriginal\":1000,"
                                + "\"plazoCuotas\":3,\"cuotas\":[]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("datos_invalidos"));
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

    /** Las tres primeras filas del plan real, con la primera ya pagada. */
    private String crearCredito() throws Exception {
        String cuerpo = """
                {
                  "entidad": "Bancamía",
                  "numeroOperacion": "31639650 0",
                  "descripcion": "Agromía Inversión",
                  "montoOriginal": 4371000.00,
                  "tasaEa": 76.0,
                  "plazoCuotas": 3,
                  "diaPago": 2,
                  "fechaVencimiento": "2026-11-02",
                  "cuotas": [
                    {"numero":1,"fecha":"2026-09-02","dias":32,"saldoCapital":4226306.32,
                     "capital":0.00,"interes":0.00,"valorCuota":0.00,"pagada":true,
                     "fechaPago":"2026-09-02"},
                    {"numero":2,"fecha":"2026-10-02","dias":30,"saldoCapital":4226306.32,
                     "capital":166085.74,"interes":203863.36,"mipyme":32570.00,"seguro":1785.10,
                     "valorCuota":404304.00},
                    {"numero":3,"fecha":"2026-11-02","dias":30,"saldoCapital":4060220.58,
                     "capital":174097.18,"interes":195851.92,"mipyme":32570.00,"seguro":1715.46,
                     "valorCuota":404235.00}
                  ]
                }
                """;

        String respuesta = mvc.perform(auth(post("/api/creditos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private String idDeLaCuota(String creditoId, int indice) throws Exception {
        String respuesta = mvc.perform(auth(get("/api/creditos/" + creditoId + "/cuotas")))
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get(indice).get("id").asText();
    }
}
