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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Corrección de pagos mal registrados y métricas para planificar un mes por adelantado.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Corrección de pagos y estimación del mes")
class CorreccionYEstimacionTest {

    private static final String PASSWORD = "unaClaveSegura123";

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
        token = registrar();
    }

    @Nested
    @DisplayName("Corregir un pago")
    class Correccion {

        @Test
        void deshace_un_pago_apuntado_por_error() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();
            String arriendo = idDelGasto(mesId, "Tía (arriendo y comida)");

            pagar(arriendo);

            // Resulta que no se había pagado nada.
            corregir(arriendo, 0)
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.estado").value("PENDIENTE"))
                    .andExpect(jsonPath("$.montoPagado").value(0))
                    .andExpect(jsonPath("$.fechaPago").doesNotExist());
        }

        @Test
        void ajusta_un_pago_que_resulto_ser_parcial() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();
            String arriendo = idDelGasto(mesId, "Tía (arriendo y comida)");

            pagar(arriendo);

            corregir(arriendo, 400000)
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.estado").value("PARCIAL"))
                    .andExpect(jsonPath("$.montoPagado").value(400000))
                    .andExpect(jsonPath("$.saldoPendiente").value(200000));
        }

        /**
         * El calendario determina cuánto cuesta el transporte, no si ya se pagó. Que el gasto
         * no sea editable no debe impedir corregir su pago.
         */
        @Test
        void el_pago_del_transporte_tambien_se_corrige() throws Exception {
            UUID mesId = crearMes();
            String transporte = idDelGastoDeTransporte(mesId);

            pagar(transporte);

            corregir(transporte, 50000)
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.estado").value("PARCIAL"))
                    .andExpect(jsonPath("$.montoPagado").value(50000));
        }

        @Test
        void corregir_a_cero_devuelve_el_dinero_al_disponible() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();
            String arriendo = idDelGasto(mesId, "Tía (arriendo y comida)");

            pagar(arriendo);
            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.disponibleHoy").value(2574000));

            corregir(arriendo, 0).andExpect(status().isOk());

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.disponibleHoy").value(3174000));
        }

        @Test
        void rechaza_corregir_por_encima_del_valor_del_gasto() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();

            corregir(idDelGasto(mesId, "Celular"), 999999)
                    .andExpect(status().isBadRequest());
        }

        @Test
        void rechaza_un_monto_negativo() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();

            corregir(idDelGasto(mesId, "Celular"), -1000)
                    .andExpect(status().isBadRequest());
        }
    }

    @Nested
    @DisplayName("Cuánto del sueldo tiene destino")
    class Compromiso {

        /**
         * En un mes que aún no ha empezado no hay ningún pago hecho: las cifras de lo pagado son
         * todas cero y no dicen nada. Lo comprometido sí, y es lo que permite planificar.
         */
        @Test
        void cuenta_lo_previsto_aunque_no_se_haya_pagado_nada() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.gastoPagado").value(0))
                    .andExpect(jsonPath("$.comprometido").value(1132000))
                    // 1.132.000 sobre 3.174.000
                    .andExpect(jsonPath("$.porcentajeComprometido").value(35.66));
        }

        @Test
        void los_abonos_a_deudas_tambien_ocupan_cupo() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();
            String deudaId = crearDeuda();

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(cuerpoAbono(500000, mesId)));

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.comprometido").value(1632000));
        }

        @Test
        void sin_ingreso_registrado_el_porcentaje_es_cero() throws Exception {
            // Evita una división por cero al montar un mes antes de saber el sueldo.
            UUID mesId = crearMesSinIngreso();

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.porcentajeComprometido").value(0));
        }

        @Test
        void pagar_no_cambia_lo_comprometido() throws Exception {
            // Pagar no reduce el compromiso: solo mueve dinero de pendiente a pagado.
            crearPlantillas();
            UUID mesId = crearMes();

            pagar(idDelGasto(mesId, "Celular"));

            mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                    .andExpect(jsonPath("$.comprometido").value(1132000))
                    .andExpect(jsonPath("$.gastoPagado").value(100000));
        }
    }

    @Nested
    @DisplayName("Traer los gastos fijos a un mes ya creado")
    class AplicarPlantillas {

        /**
         * Las plantillas se copian al crear el mes. Una configurada después no aparece sola en
         * los meses que ya existían, y es justo lo que pasa al empezar a usar la aplicación:
         * primero se crea el mes y luego se caen en la cuenta los gastos fijos.
         */
        @Test
        void anade_las_plantillas_creadas_despues_del_mes() throws Exception {
            UUID mesId = crearMes();

            // Recién creado solo tiene el gasto de transporte.
            mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                    .andExpect(jsonPath("$.length()").value(1));

            crearPlantillas();

            mvc.perform(auth(post("/api/meses/" + mesId + "/aplicar-plantillas")))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.length()").value(5));

            mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                    .andExpect(jsonPath("$.length()").value(6));
        }

        @Test
        void repetirlo_no_duplica_nada() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();

            mvc.perform(auth(post("/api/meses/" + mesId + "/aplicar-plantillas")))
                    .andExpect(jsonPath("$.length()").value(0));

            mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                    .andExpect(jsonPath("$.length()").value(6));
        }

        @Test
        void no_pisa_los_importes_ya_ajustados() throws Exception {
            crearPlantillas();
            UUID mesId = crearMes();
            String celular = idDelGasto(mesId, "Celular");

            // Este mes el celular salió más caro.
            mvc.perform(auth(patch("/api/gastos/" + celular))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(cuerpoMonto(180000)));

            mvc.perform(auth(post("/api/meses/" + mesId + "/aplicar-plantillas")))
                    .andExpect(jsonPath("$.length()").value(0));

            mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                    .andExpect(jsonPath("$[?(@.nombre=='Celular')].monto").value(180000.0));
        }

        @Test
        void las_plantillas_desactivadas_no_se_traen() throws Exception {
            UUID mesId = crearMes();
            crearPlantilla("Gimnasio", "DEPORTE", 80000);

            String plantillaId = json.readTree(
                            mvc.perform(auth(get("/api/plantillas")))
                                    .andReturn().getResponse().getContentAsString())
                    .get(0).get("id").asText();

            mvc.perform(auth(post("/api/plantillas/" + plantillaId + "/desactivar")))
                    .andExpect(status().isNoContent());

            mvc.perform(auth(post("/api/meses/" + mesId + "/aplicar-plantillas")))
                    .andExpect(jsonPath("$.length()").value(0));
        }
    }

    @Nested
    @DisplayName("Editar una deuda")
    class EdicionDeDeudas {

        @Test
        void cambia_los_datos_sin_tocar_el_saldo() throws Exception {
            String deudaId = crearDeuda();

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(cuerpoAbono(500000, null)));

            mvc.perform(auth(patch("/api/deudas/" + deudaId))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoEdicionDeuda()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.acreedor").value("Tarjeta Davivienda"))
                    .andExpect(jsonPath("$.tasaInteresMensual").value(1.5))
                    // El abono ya hecho no se ve afectado por editar los datos.
                    .andExpect(jsonPath("$.saldo").value(1500000));
        }

        /**
         * Corregir un importe mal apuntado no debe borrar los pagos hechos: lo que cambia es la
         * deuda, no el historial.
         */
        @Test
        void corregir_el_importe_conserva_lo_ya_abonado() throws Exception {
            String deudaId = crearDeuda();

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(cuerpoAbono(500000, null)));

            // Eran un millón y medio, no dos millones.
            mvc.perform(auth(patch("/api/deudas/" + deudaId))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoMontoOriginal(1500000)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.montoOriginal").value(1500000))
                    // 1.500.000 menos los 500.000 ya abonados
                    .andExpect(jsonPath("$.saldo").value(1000000))
                    .andExpect(jsonPath("$.porcentajePagado").value(33.33));
        }

        @Test
        void corregir_al_valor_ya_abonado_salda_la_deuda() throws Exception {
            String deudaId = crearDeuda();

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(cuerpoAbono(500000, null)));

            mvc.perform(auth(patch("/api/deudas/" + deudaId))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoMontoOriginal(500000)))
                    .andExpect(jsonPath("$.saldo").value(0))
                    .andExpect(jsonPath("$.activa").value(false));
        }

        @Test
        void rechaza_un_importe_menor_que_lo_ya_abonado() throws Exception {
            String deudaId = crearDeuda();

            mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(cuerpoAbono(500000, null)));

            // Implicaría haber pagado más de lo que se debía.
            mvc.perform(auth(patch("/api/deudas/" + deudaId))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoMontoOriginal(300000)))
                    .andExpect(status().isBadRequest());
        }

        @Test
        void recalcula_el_interes_con_la_tasa_nueva() throws Exception {
            String deudaId = crearDeuda();

            mvc.perform(auth(patch("/api/deudas/" + deudaId))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoEdicionDeuda()))
                    // 2.000.000 al 1,5% son 30.000
                    .andExpect(jsonPath("$.interesMensualEstimado").value(30000));
        }
    }

    // --- utilidades ---

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder peticion) {
        return peticion.header("Authorization", "Bearer " + token);
    }

    private String registrar() throws Exception {
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoRegistro()))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }

    private UUID crearMes() throws Exception {
        return crearMesCon(3174000);
    }

    private UUID crearMesSinIngreso() throws Exception {
        return crearMesCon(0);
    }

    private UUID crearMesCon(int ingreso) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/meses"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoMes(ingreso)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(json.readTree(respuesta).get("id").asText());
    }

    private void crearPlantillas() throws Exception {
        crearPlantilla("Tía (arriendo y comida)", "VIVIENDA", 600000);
        crearPlantilla("Karate", "DEPORTE", 150000);
        crearPlantilla("Celular", "SERVICIOS", 100000);
        crearPlantilla("Claude Code", "HERRAMIENTAS", 90000);
        crearPlantilla("YouTube, Netflix y Spotify", "SUSCRIPCIONES", 50000);
    }

    private void crearPlantilla(String nombre, String categoria, int monto) throws Exception {
        mvc.perform(auth(post("/api/plantillas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoPlantilla(nombre, categoria, monto)))
                .andExpect(status().isCreated());
    }

    private String crearDeuda() throws Exception {
        String respuesta = mvc.perform(auth(post("/api/deudas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoDeuda()))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private void pagar(String gastoId) throws Exception {
        mvc.perform(auth(post("/api/gastos/" + gastoId + "/pagar"))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isOk());
    }

    private org.springframework.test.web.servlet.ResultActions corregir(String gastoId,
                                                                       int montoPagado)
            throws Exception {
        return mvc.perform(auth(post("/api/gastos/" + gastoId + "/corregir-pago"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(cuerpoCorreccion(montoPagado)));
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

    // Los cuerpos JSON se construyen aparte para no anidar comillas dentro de los casos.

    private static String cuerpoRegistro() {
        return "{\"email\":\"duvan@axchisan.com\",\"password\":\"" + PASSWORD
                + "\",\"nombre\":\"Duvan\"}";
    }

    private static String cuerpoMes(int ingreso) {
        return "{\"anio\":2026,\"mes\":8,\"ingresoBase\":" + ingreso + ",\"valorPasaje\":3550}";
    }

    private static String cuerpoPlantilla(String nombre, String categoria, int monto) {
        return "{\"nombre\":\"" + nombre + "\",\"categoria\":\"" + categoria
                + "\",\"montoDefault\":" + monto + "}";
    }

    private static String cuerpoDeuda() {
        return "{\"acreedor\":\"Tarjeta Bancolombia\",\"tipo\":\"TARJETA_CREDITO\","
                + "\"montoOriginal\":2000000}";
    }

    private static String cuerpoEdicionDeuda() {
        return "{\"acreedor\":\"Tarjeta Davivienda\",\"tasaInteresMensual\":1.5}";
    }

    private static String cuerpoAbono(int monto, UUID mesId) {
        String mes = mesId == null ? "" : ",\"mesId\":\"" + mesId + "\"";
        return "{\"monto\":" + monto + mes + "}";
    }

    private static String cuerpoMontoOriginal(int monto) {
        return "{\"montoOriginal\":" + monto + "}";
    }

    private static String cuerpoMonto(int monto) {
        return "{\"monto\":" + monto + "}";
    }

    private static String cuerpoCorreccion(int montoPagado) {
        return "{\"montoPagado\":" + montoPagado + "}";
    }
}
