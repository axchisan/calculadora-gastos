package com.axchisan.gastos.api;

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
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Prueba el presupuesto completo con el escenario real de uso: sueldo de $3.174.000, los gastos
 * fijos habituales y el transporte de agosto de 2026 con pasaje de $3.550.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("API del presupuesto mensual")
class PresupuestoIntegracionTest {

    private static final String PASSWORD = "unaClaveSegura123";
    private static final int ANIO = 2026;
    private static final int MES = 8;

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private PlantillaGastoRepository plantillas;
    @Autowired private DeudaRepository deudas;
    @Autowired private MetaAhorroRepository metas;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        refrescos.deleteAll();
        meses.deleteAll();
        plantillas.deleteAll();
        deudas.deleteAll();
        metas.deleteAll();
        usuarios.deleteAll();
        token = registrar("duvan@axchisan.com");
    }

    @Nested
    @DisplayName("Creación del mes")
    class CreacionDelMes {

        @Test
        void copiaLasPlantillasDeGastosFijos() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();

            mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                    .andExpect(status().isOk())
                    // Los cinco gastos fijos más el de transporte que genera el sistema.
                    .andExpect(jsonPath("$.length()").value(6));
        }

        @Test
        void noCopiaLasPlantillasDesactivadas() throws Exception {
            crearPlantillasHabituales();
            String plantillaId = crearPlantilla("Gimnasio", "DEPORTE", 80000);
            mvc.perform(auth(post("/api/plantillas/" + plantillaId + "/desactivar")))
                    .andExpect(status().isNoContent());

            UUID mesId = crearMes();

            mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                    .andExpect(jsonPath("$.length()").value(6));
        }

        @Test
        void rechazaCrearDosVecesElMismoMes() throws Exception {
            crearMes();

            mvc.perform(auth(post("/api/meses"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"anio":%d,"mes":%d,"ingresoBase":3174000,"valorPasaje":3550}"""
                                    .formatted(ANIO, MES)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.error").value("mes_ya_existe"));
        }

        @Test
        void rechazaUnMesFueraDeRango() throws Exception {
            mvc.perform(auth(post("/api/meses"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"anio":2026,"mes":13,"ingresoBase":3174000}"""))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.campos.mes").isNotEmpty());
        }
    }

    @Nested
    @DisplayName("Transporte del mes")
    class Transporte {

        /**
         * Agosto de 2026 tiene 19 días hábiles (21 de lunes a viernes menos el 7, Batalla de
         * Boyacá, y el 17, Asunción). Con un día remoto por semana se propone el viernes, y como
         * el 7 es festivo quedan tres días desde casa: 16 días de oficina × 2 pasajes más 8 días
         * de karate × 1 pasaje extra = 40 pasajes × $3.550 = $142.000.
         */
        @Test
        void calculaElMesConLosFestivosColombianos() throws Exception {
            UUID mesId = crearMes();

            mvc.perform(auth(get("/api/meses/" + mesId + "/transporte")))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.diasOficina").value(16))
                    .andExpect(jsonPath("$.diasRemotos").value(3))
                    .andExpect(jsonPath("$.diasFestivos").value(2))
                    .andExpect(jsonPath("$.diasKarate").value(8))
                    .andExpect(jsonPath("$.totalPasajes").value(40))
                    .andExpect(jsonPath("$.costoTotal").value(142000))
                    .andExpect(jsonPath("$.dias.length()").value(31));
        }

        @Test
        void generaElGastoDeTransporteDentroDelPresupuesto() throws Exception {
            UUID mesId = crearMes();

            // El monto llega con la escala 2 de la columna numeric, de ahí el decimal.
            mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                    .andExpect(jsonPath("$[?(@.origen=='TRANSPORTE')].monto").value(142000.0))
                    // Lo mantiene el calendario, así que no admite edición directa.
                    .andExpect(jsonPath("$[?(@.origen=='TRANSPORTE')].editable").value(false));
        }

        @Test
        void marcarUnDiaComoRemotoAbarataElMes() throws Exception {
            UUID mesId = crearMes();
            // Lunes 3 de agosto, día de oficina sin karate: pasa de 2 pasajes a 0.
            String diaId = idDelDia(mesId, "2026-08-03");

            mvc.perform(auth(patch("/api/meses/" + mesId + "/transporte/dias/" + diaId + "/tipo"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"tipo":"REMOTO"}"""))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.totalPasajes").value(38))
                    .andExpect(jsonPath("$.costoTotal").value(134900));
        }

        @Test
        void cambiarLaTarifaRecalculaSinPerderLosAjustes() throws Exception {
            UUID mesId = crearMes();
            String diaId = idDelDia(mesId, "2026-08-03");
            mvc.perform(auth(patch("/api/meses/" + mesId + "/transporte/dias/" + diaId + "/tipo"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""
                            {"tipo":"REMOTO"}"""));

            mvc.perform(auth(patch("/api/meses/" + mesId + "/transporte/configuracion"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"valorPasaje":4000}"""))
                    .andExpect(status().isOk())
                    // El día remoto se conserva: siguen siendo 38 pasajes, ahora a $4.000.
                    .andExpect(jsonPath("$.totalPasajes").value(38))
                    .andExpect(jsonPath("$.costoTotal").value(152000));
        }

        @Test
        void ofreceLasTresProyeccionesDelMes() throws Exception {
            UUID mesId = crearMes();

            mvc.perform(auth(get("/api/meses/" + mesId + "/transporte/escenarios")))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.pesimista.costoTotal").value(163300))
                    .andExpect(jsonPath("$.esperado.costoTotal").value(142000))
                    .andExpect(jsonPath("$.optimista.costoTotal").value(113600))
                    .andExpect(jsonPath("$.rango").value(49700));
        }

        @Test
        void elGastoDeTransporteNoSeEditaDirectamente() throws Exception {
            UUID mesId = crearMes();
            String gastoId = idDelGastoDeTransporte(mesId);

            mvc.perform(auth(patch("/api/gastos/" + gastoId))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"monto":999999}"""))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.error").value("gasto_no_editable"));
        }
    }

    @Nested
    @DisplayName("Resumen del mes")
    class Resumen {

        /**
         * Los gastos fijos suman $990.000 y el transporte $142.000, en total $1.132.000. Con un
         * sueldo de $3.174.000, el mes cierra con $2.042.000.
         */
        @Test
        void calculaElSaldoConLosGastosFijosYElTransporte() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.ingresoTotal").value(3174000))
                    .andExpect(jsonPath("$.gastoTotal").value(1132000))
                    .andExpect(jsonPath("$.gastoPagado").value(0))
                    .andExpect(jsonPath("$.gastoPendiente").value(1132000))
                    .andExpect(jsonPath("$.saldoProyectado").value(2042000))
                    // Nada pagado todavía, así que en la mano sigue estando el sueldo completo.
                    .andExpect(jsonPath("$.disponibleHoy").value(3174000));
        }

        @Test
        void pagarUnGastoReduceElDisponiblePeroNoElSaldoProyectado() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();
            String arriendo = idDelGasto(mesId, "Tía (arriendo y comida)");

            mvc.perform(auth(post("/api/gastos/" + arriendo + "/pagar"))
                            .contentType(MediaType.APPLICATION_JSON).content("{}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.estado").value("PAGADO"))
                    .andExpect(jsonPath("$.saldoPendiente").value(0));

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.gastoPagado").value(600000))
                    .andExpect(jsonPath("$.disponibleHoy").value(2574000))
                    // El total del mes no cambia: solo se adelantó un pago que ya estaba previsto.
                    .andExpect(jsonPath("$.saldoProyectado").value(2042000));
        }

        @Test
        void admiteAbonosParciales() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();
            String arriendo = idDelGasto(mesId, "Tía (arriendo y comida)");

            mvc.perform(auth(post("/api/gastos/" + arriendo + "/abonar"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"importe":250000}"""))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.estado").value("PARCIAL"))
                    .andExpect(jsonPath("$.montoPagado").value(250000))
                    .andExpect(jsonPath("$.saldoPendiente").value(350000));
        }

        @Test
        void rechazaAbonarMasDeLoQueValeElGasto() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();
            String celular = idDelGasto(mesId, "Celular");

            mvc.perform(auth(post("/api/gastos/" + celular + "/abonar"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"importe":500000}"""))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.error").value("peticion_invalida"));
        }

        @Test
        void losIngresosExtraSoloCuentanCuandoSeCobran() throws Exception {
            UUID mesId = crearMes();

            mvc.perform(auth(post("/api/meses/" + mesId + "/ingresos"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"concepto":"Prima","monto":1500000,"fecha":"2026-08-15",\
                                    "recibido":false}"""))
                    .andExpect(status().isCreated());

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    // Aún sin cobrar: no suma al disponible...
                    .andExpect(jsonPath("$.ingresoTotal").value(3174000))
                    // ...pero sí a la proyección del cierre.
                    .andExpect(jsonPath("$.ingresoProyectado").value(4674000));
        }
    }

    @Nested
    @DisplayName("Deudas")
    class Deudas {

        @Test
        void abonarReduceElSaldoYSumaAlMes() throws Exception {
            UUID mesId = crearMes();
            String deudaId = crearDeuda("Tarjeta Bancolombia", "TARJETA_CREDITO", 2000000);

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"monto":500000,"mesId":"%s"}""".formatted(mesId)))
                    .andExpect(status().isCreated());

            mvc.perform(auth(get("/api/deudas/" + deudaId)))
                    .andExpect(jsonPath("$.saldo").value(1500000))
                    .andExpect(jsonPath("$.porcentajePagado").value(25.00));

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.abonosDeuda").value(500000))
                    .andExpect(jsonPath("$.deudaTotal").value(1500000));
        }

        @Test
        void saldarLaDeudaLaDesactiva() throws Exception {
            String deudaId = crearDeuda("Papá", "FAMILIAR", 300000);

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""
                            {"monto":300000}"""));

            mvc.perform(auth(get("/api/deudas/" + deudaId)))
                    .andExpect(jsonPath("$.saldo").value(0))
                    .andExpect(jsonPath("$.activa").value(false));
        }

        @Test
        void rechazaAbonarMasDelSaldo() throws Exception {
            String deudaId = crearDeuda("Papá", "FAMILIAR", 300000);

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"monto":400000}"""))
                    .andExpect(status().isBadRequest());
        }

        @Test
        void eliminarUnAbonoDevuelveElSaldo() throws Exception {
            String deudaId = crearDeuda("Amigo", "AMIGO", 500000);
            String respuesta = mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"monto":200000}"""))
                    .andReturn().getResponse().getContentAsString();
            String abonoId = json.readTree(respuesta).get("id").asText();

            mvc.perform(auth(delete("/api/deudas/abonos/" + abonoId)))
                    .andExpect(status().isNoContent());

            mvc.perform(auth(get("/api/deudas/" + deudaId)))
                    .andExpect(jsonPath("$.saldo").value(500000))
                    .andExpect(jsonPath("$.activa").value(true));
        }
    }

    @Nested
    @DisplayName("Ahorro")
    class Ahorro {

        @Test
        void aportarAumentaElSaldoDeLaMeta() throws Exception {
            String metaId = crearMeta("Fondo de emergencia", "PORCENTAJE_SOBRANTE", 50);

            mvc.perform(auth(post("/api/ahorro/metas/" + metaId + "/movimientos"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"tipo":"APORTE","monto":400000}"""))
                    .andExpect(status().isCreated());

            mvc.perform(auth(get("/api/ahorro/metas")))
                    .andExpect(jsonPath("$[0].saldoAcumulado").value(400000));
        }

        @Test
        void rechazaRetirarMasDeLoAhorrado() throws Exception {
            String metaId = crearMeta("Viaje", "MONTO_FIJO", 200000);

            mvc.perform(auth(post("/api/ahorro/metas/" + metaId + "/movimientos"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""
                            {"tipo":"APORTE","monto":100000}"""));

            mvc.perform(auth(post("/api/ahorro/metas/" + metaId + "/movimientos"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"tipo":"RETIRO","monto":150000}"""))
                    .andExpect(status().isBadRequest());
        }

        @Test
        void rechazaUnPorcentajeMayorAlCienPorCiento() throws Exception {
            mvc.perform(auth(post("/api/ahorro/metas"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"nombre":"Imposible","tipoAsignacion":"PORCENTAJE_INGRESO",\
                                    "valor":150}"""))
                    .andExpect(status().isBadRequest());
        }

        /**
         * Dos metas al 50% del sobrante no se llevan el 100%: la segunda calcula sobre lo que
         * queda tras la primera.
         */
        @Test
        void elPorcentajeDelSobranteSeAplicaEnCascada() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();
            crearMeta("Emergencia", "PORCENTAJE_SOBRANTE", 50);
            crearMeta("Viaje", "PORCENTAJE_SOBRANTE", 50);

            // Saldo proyectado: $2.042.000 → primera meta 50% = $1.021.000,
            // segunda 50% del resto = $510.500.
            mvc.perform(auth(get("/api/ahorro/distribucion/" + mesId)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.length()").value(2))
                    .andExpect(jsonPath("$[0].monto").value(1021000))
                    .andExpect(jsonPath("$[1].monto").value(510500));
        }
    }

    @Nested
    @DisplayName("Aislamiento entre usuarios")
    class Aislamiento {

        @Test
        void unUsuarioNoAccedeAlMesDeOtro() throws Exception {
            UUID mesDeDuvan = crearMes();
            String tokenAjeno = registrar("otro@axchisan.com");

            mvc.perform(get("/api/meses/" + mesDeDuvan + "/resumen")
                            .header("Authorization", "Bearer " + tokenAjeno))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.error").value("no_encontrado"));
        }

        @Test
        void unUsuarioNoVeLosGastosDeOtro() throws Exception {
            crearPlantillasHabituales();
            UUID mesDeDuvan = crearMes();
            String tokenAjeno = registrar("otro@axchisan.com");

            mvc.perform(get("/api/meses/" + mesDeDuvan + "/gastos")
                            .header("Authorization", "Bearer " + tokenAjeno))
                    .andExpect(status().isNotFound());
        }

        @Test
        void cadaUsuarioSoloVeSusPropiasDeudas() throws Exception {
            crearDeuda("Tarjeta", "TARJETA_CREDITO", 1000000);
            String tokenAjeno = registrar("otro@axchisan.com");

            mvc.perform(get("/api/deudas").header("Authorization", "Bearer " + tokenAjeno))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.length()").value(0));
        }

        @Test
        void unUsuarioNoModificaElGastoDeOtro() throws Exception {
            crearPlantillasHabituales();
            UUID mesDeDuvan = crearMes();
            String gastoId = idDelGasto(mesDeDuvan, "Celular");
            String tokenAjeno = registrar("otro@axchisan.com");

            mvc.perform(patch("/api/gastos/" + gastoId)
                            .header("Authorization", "Bearer " + tokenAjeno)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"monto":1}"""))
                    .andExpect(status().isNotFound());
        }
    }

    @Nested
    @DisplayName("Cierre del mes")
    class Cierre {

        @Test
        void unMesCerradoNoAdmiteCambios() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();
            String celular = idDelGasto(mesId, "Celular");

            mvc.perform(auth(post("/api/meses/" + mesId + "/cerrar")))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.cerrado").value(true));

            mvc.perform(auth(post("/api/gastos/" + celular + "/pagar"))
                            .contentType(MediaType.APPLICATION_JSON).content("{}"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.error").value("mes_cerrado"));
        }

        @Test
        void reabrirDevuelveLaCapacidadDeEditar() throws Exception {
            crearPlantillasHabituales();
            UUID mesId = crearMes();
            String celular = idDelGasto(mesId, "Celular");

            mvc.perform(auth(post("/api/meses/" + mesId + "/cerrar")));
            mvc.perform(auth(post("/api/meses/" + mesId + "/reabrir")))
                    .andExpect(jsonPath("$.cerrado").value(false));

            mvc.perform(auth(post("/api/gastos/" + celular + "/pagar"))
                            .contentType(MediaType.APPLICATION_JSON).content("{}"))
                    .andExpect(status().isOk());
        }
    }

    // --- utilidades ---

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder peticion) {
        return peticion.header("Authorization", "Bearer " + token);
    }

    private String registrar(String email) throws Exception {
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"%s","nombre":"Duvan"}"""
                                .formatted(email, PASSWORD)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }

    private UUID crearMes() throws Exception {
        String respuesta = mvc.perform(auth(post("/api/meses"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"anio":%d,"mes":%d,"ingresoBase":3174000,"valorPasaje":3550}"""
                                .formatted(ANIO, MES)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(json.readTree(respuesta).get("id").asText());
    }

    private void crearPlantillasHabituales() throws Exception {
        crearPlantilla("Tía (arriendo y comida)", "VIVIENDA", 600000);
        crearPlantilla("Karate", "DEPORTE", 150000);
        crearPlantilla("Celular", "SERVICIOS", 100000);
        crearPlantilla("Claude Code", "HERRAMIENTAS", 90000);
        crearPlantilla("YouTube, Netflix y Spotify", "SUSCRIPCIONES", 50000);
    }

    private String crearPlantilla(String nombre, String categoria, int monto) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/plantillas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nombre":"%s","categoria":"%s","montoDefault":%d}"""
                                .formatted(nombre, categoria, monto)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private String crearDeuda(String acreedor, String tipo, int monto) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/deudas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"acreedor":"%s","tipo":"%s","montoOriginal":%d}"""
                                .formatted(acreedor, tipo, monto)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private String crearMeta(String nombre, String tipo, int valor) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/ahorro/metas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nombre":"%s","tipoAsignacion":"%s","valor":%d}"""
                                .formatted(nombre, tipo, valor)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private String idDelGasto(UUID mesId, String nombre) throws Exception {
        JsonNode gastos = json.readTree(mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                .andReturn().getResponse().getContentAsString());
        for (JsonNode gasto : gastos) {
            if (nombre.equals(gasto.get("nombre").asText())) {
                return gasto.get("id").asText();
            }
        }
        throw new AssertionError("No se encontró el gasto '" + nombre + "'");
    }

    private String idDelGastoDeTransporte(UUID mesId) throws Exception {
        JsonNode gastos = json.readTree(mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                .andReturn().getResponse().getContentAsString());
        for (JsonNode gasto : gastos) {
            if ("TRANSPORTE".equals(gasto.get("origen").asText())) {
                return gasto.get("id").asText();
            }
        }
        throw new AssertionError("No se generó el gasto de transporte");
    }

    private String idDelDia(UUID mesId, String fecha) throws Exception {
        JsonNode resumen = json.readTree(
                mvc.perform(auth(get("/api/meses/" + mesId + "/transporte")))
                        .andReturn().getResponse().getContentAsString());
        for (JsonNode dia : resumen.get("dias")) {
            if (fecha.equals(dia.get("fecha").asText())) {
                return dia.get("id").asText();
            }
        }
        throw new AssertionError("No se encontró el día " + fecha);
    }

    @Test
    @DisplayName("El identificador generado es un UUID versión 7")
    void losIdentificadoresSonUuidV7() throws Exception {
        UUID mesId = crearMes();
        // La versión ocupa los bits 12-15 del tercer grupo del UUID.
        assertThat(mesId.version()).isEqualTo(7);
    }
}
