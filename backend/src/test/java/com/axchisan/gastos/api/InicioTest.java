package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CreditoRepository;
import com.axchisan.gastos.repositorio.CuentaRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.axchisan.gastos.servicio.ServicioInicio;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * La pantalla de Inicio en una sola petición, y la revalidación barata con {@code ETag}.
 *
 * <p>Todas las cifras son inventadas. El día de referencia es el 20 de agosto de 2026: el mes
 * presupuestal en curso es agosto (28 jul – 27 ago) y el horizonte llega al 19 de septiembre.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Inicio")
class InicioTest {

    private static final String PASSWORD = "unaClaveSegura123";
    private static final String HOY = "2026-08-20";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private CreditoRepository creditos;
    @Autowired private DeudaRepository deudas;
    @Autowired private CuentaRepository cuentas;
    @Autowired private FuenteIngresoRepository fuentes;

    private String token;

    @BeforeEach
    void preparar() throws Exception {
        creditos.deleteAll();
        deudas.deleteAll();
        cuentas.deleteAll();
        fuentes.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();
    }

    // --- el mes presupuestal ---

    @Test
    void el_mes_presupuestal_empieza_el_28() {
        assertThat(ServicioInicio.periodoDe(LocalDate.parse("2026-08-27")))
                .isEqualTo(YearMonth.of(2026, 8));
        assertThat(ServicioInicio.periodoDe(LocalDate.parse("2026-08-28")))
                .isEqualTo(YearMonth.of(2026, 9));
        assertThat(ServicioInicio.periodoDe(LocalDate.parse("2026-12-31")))
                .isEqualTo(YearMonth.of(2027, 1));
    }

    @Test
    void un_dia_de_vencimiento_cae_dentro_de_su_mes_presupuestal() {
        // Septiembre va del 28 de agosto al 27 de septiembre.
        assertThat(ServicioInicio.vencimientoEn(YearMonth.of(2026, 9), 4))
                .isEqualTo(LocalDate.parse("2026-09-04"));
        assertThat(ServicioInicio.vencimientoEn(YearMonth.of(2026, 9), 30))
                .isEqualTo(LocalDate.parse("2026-08-30"));
        // Marzo empieza en febrero, que no tiene 30: se ajusta a su último día.
        assertThat(ServicioInicio.vencimientoEn(YearMonth.of(2026, 3), 30))
                .isEqualTo(LocalDate.parse("2026-02-28"));
    }

    // --- el contenido ---

    @Test
    void sin_el_mes_creado_responde_igual_sin_resumen() throws Exception {
        mvc.perform(auth(get("/api/inicio?fecha=" + HOY)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.periodo").value("2026-08"))
                .andExpect(jsonPath("$.resumen").doesNotExist())
                .andExpect(jsonPath("$.cuentas.length()").value(0))
                .andExpect(jsonPath("$.proximosPagos.length()").value(0));
    }

    @Test
    void trae_el_resumen_del_mes_y_las_cuentas() throws Exception {
        crearMes(2026, 8);
        enviar(post("/api/cuentas"),
                "{\"nombre\":\"Banco\",\"tipo\":\"BANCO\",\"saldo\":120000}");

        mvc.perform(auth(get("/api/inicio?fecha=" + HOY)))
                .andExpect(jsonPath("$.hoy").value(HOY))
                .andExpect(jsonPath("$.resumen.periodo").value("2026-08"))
                .andExpect(jsonPath("$.resumen.ingresoBase").value(2000000))
                .andExpect(jsonPath("$.cuentas[0].nombre").value("Banco"))
                .andExpect(jsonPath("$.cuentas[0].saldo").value(120000));
    }

    @Test
    void junta_gastos_cuotas_deudas_y_sueldo_en_orden() throws Exception {
        UUID agosto = crearMes(2026, 8);
        UUID septiembre = crearMes(2026, 9);

        crearGasto(agosto, "Arriendo", 500000, 5);          // venció el 5 de agosto
        crearGasto(agosto, "Celular", 50000, null);          // del mes, sin día fijo
        UUID pagado = crearGasto(agosto, "Gimnasio", 80000, 10);
        enviar(post("/api/gastos/" + pagado + "/pagar"), "{}");
        crearGasto(agosto, "Transporte", 0, null);           // en cero: no se cobra nada
        crearGasto(septiembre, "Tarjeta", 200000, 4);        // 4 de septiembre
        crearGasto(septiembre, "Seguro", 30000, 30);         // 30 de agosto
        crearGasto(septiembre, "Internet", 60000, null);     // del mes siguiente, sin día: no
        crearGasto(septiembre, "Lejano", 10000, 25);         // 25 de septiembre: fuera

        crearCredito();
        enviar(post("/api/deudas"), """
                {"acreedor":"Prestamista","tipo":"PRESTAMO_BANCARIO","montoOriginal":150000,
                 "fechaInicio":"2026-08-01",
                 "fechaLimite":"2026-09-04"}
                """);
        enviar(post("/api/deudas"), """
                {"acreedor":"Sin fecha","tipo":"FAMILIAR","montoOriginal":90000}
                """);
        enviar(post("/api/sueldo"), """
                {"nombre":"Empresa","montoMensual":1000,"fechaInicio":"2026-06-01",
                 "medio":"TRANSFERENCIA","trm":4000,"cuentaDestino":"Banco"}
                """);

        JsonNode proximos = leerInicio().get("proximosPagos");
        List<String> titulos = new ArrayList<>();
        proximos.forEach(p -> titulos.add(p.get("titulo").asText()));

        assertThat(titulos).containsExactly(
                // Lo vencido primero, por fecha.
                "Arriendo", "Cuota 2 · Banco Uno",
                // Lo del mes sin día fijo.
                "Celular",
                // Y lo que viene, por fecha.
                "Seguro", "Sueldo Empresa", "Prestamista", "Tarjeta", "Cuota 3 · Banco Uno");

        JsonNode arriendo = proximos.get(0);
        assertThat(arriendo.get("tipo").asText()).isEqualTo("GASTO");
        assertThat(arriendo.get("vencido").asBoolean()).isTrue();
        assertThat(arriendo.get("fecha").asText()).isEqualTo("2026-08-05");
        assertThat(arriendo.get("monto").decimalValue()).isEqualByComparingTo("500000");

        JsonNode celular = proximos.get(2);
        assertThat(celular.has("fecha")).isFalse();
        assertThat(celular.get("vencido").asBoolean()).isFalse();

        JsonNode sueldo = proximos.get(4);
        assertThat(sueldo.get("tipo").asText()).isEqualTo("SUELDO");
        assertThat(sueldo.get("ingreso").asBoolean()).isTrue();
        assertThat(sueldo.get("fecha").asText()).startsWith("2026-09-0");
        assertThat(sueldo.get("fechaHasta").asText()).startsWith("2026-09-");
        assertThat(sueldo.get("detalle").asText()).isEqualTo("1.000,00 USD · llega a Banco");

        JsonNode cuota = proximos.get(7);
        assertThat(cuota.get("tipo").asText()).isEqualTo("CUOTA_CREDITO");
        assertThat(cuota.get("detalle").asText()).isEqualTo("Crédito · cuota 3 de 4");
        assertThat(cuota.get("monto").decimalValue()).isEqualByComparingTo("110000");

        JsonNode deuda = proximos.get(5);
        assertThat(deuda.get("tipo").asText()).isEqualTo("DEUDA");
        assertThat(deuda.get("detalle").asText()).isEqualTo("Pago único");
        assertThat(deuda.get("monto").decimalValue()).isEqualByComparingTo("150000");
    }

    @Test
    void un_gasto_a_medio_pagar_pide_solo_lo_que_falta() throws Exception {
        UUID agosto = crearMes(2026, 8);
        UUID celular = crearGasto(agosto, "Celular", 50000, 25);
        enviar(post("/api/gastos/" + celular + "/corregir-pago"),
                "{\"montoPagado\":20000,\"fecha\":\"2026-08-15\"}");

        JsonNode pago = leerInicio().get("proximosPagos").get(0);
        assertThat(pago.get("monto").decimalValue()).isEqualByComparingTo("30000");
        assertThat(pago.get("detalle").asText()).isEqualTo("Falta una parte");
    }

    @Test
    void el_sueldo_ya_anotado_no_vuelve_a_salir() throws Exception {
        String creada = enviar(post("/api/sueldo"), """
                {"nombre":"Empresa","montoMensual":1000,"fechaInicio":"2026-06-01",
                 "medio":"TRANSFERENCIA","trm":4000}
                """).getResponse().getContentAsString();
        String fuenteId = json.readTree(creada).get("id").asText();
        String mesDePago = leerInicio().get("proximosPagos").get(0).get("fecha").asText()
                .substring(0, 7);

        enviar(post("/api/sueldo/" + fuenteId + "/pagos"),
                "{\"mesDePago\":\"" + mesDePago + "\",\"montoPesos\":3900000}");

        assertThat(leerInicio().get("proximosPagos")).isEmpty();
    }

    // --- ETag ---

    @Test
    void una_lectura_sin_cambios_responde_304_sin_cuerpo() throws Exception {
        crearMes(2026, 8);
        MvcResult primera = mvc.perform(auth(get("/api/meses")))
                .andExpect(status().isOk())
                .andExpect(header().exists("ETag"))
                .andExpect(header().string("Cache-Control", "private, no-cache"))
                .andReturn();
        String etag = primera.getResponse().getHeader("ETag");

        MvcResult segunda = mvc.perform(auth(get("/api/meses")).header("If-None-Match", etag))
                .andExpect(status().isNotModified())
                .andReturn();
        assertThat(segunda.getResponse().getContentAsString()).isEmpty();
    }

    @Test
    void tras_un_cambio_la_huella_es_otra() throws Exception {
        crearMes(2026, 8);
        String etag = mvc.perform(auth(get("/api/meses"))).andReturn().getResponse()
                .getHeader("ETag");

        crearMes(2026, 9);

        mvc.perform(auth(get("/api/meses")).header("If-None-Match", etag))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void sin_sesion_no_hay_huella() throws Exception {
        mvc.perform(get("/api/meses"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().doesNotExist("ETag"));
    }

    @Test
    void la_web_puede_leer_la_huella_y_enviarla() throws Exception {
        mvc.perform(auth(get("/api/meses")).header("Origin", "http://localhost:5000"))
                .andExpect(header().string("Access-Control-Expose-Headers", "ETag"));
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .options("/api/meses")
                        .header("Origin", "http://localhost:5000")
                        .header("Access-Control-Request-Method", "GET")
                        .header("Access-Control-Request-Headers", "authorization,if-none-match"))
                .andExpect(status().isOk());
    }

    // --- ayudas ---

    private JsonNode leerInicio() throws Exception {
        String cuerpo = mvc.perform(auth(get("/api/inicio?fecha=" + HOY)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(cuerpo);
    }

    private UUID crearMes(int anio, int mes) throws Exception {
        String respuesta = enviar(post("/api/meses"), "{\"anio\":" + anio + ",\"mes\":" + mes
                + ",\"ingresoBase\":2000000,\"copiarPlantillas\":false}")
                .getResponse().getContentAsString();
        return UUID.fromString(json.readTree(respuesta).get("id").asText());
    }

    private UUID crearGasto(UUID mesId, String nombre, int monto, Integer dia) throws Exception {
        String respuesta = enviar(post("/api/meses/" + mesId + "/gastos"),
                "{\"nombre\":\"" + nombre + "\",\"categoria\":\"SERVICIOS\",\"monto\":" + monto
                        + (dia == null ? "" : ",\"diaVencimiento\":" + dia) + "}")
                .getResponse().getContentAsString();
        return UUID.fromString(json.readTree(respuesta).get("id").asText());
    }

    /** Cuatro cuotas: la 1 pagada, la 2 vencida, la 3 dentro del horizonte y la 4 fuera. */
    private void crearCredito() throws Exception {
        enviar(post("/api/creditos"), """
                {
                  "entidad": "Banco Uno",
                  "montoOriginal": 400000,
                  "tasaEa": 30.0,
                  "plazoCuotas": 4,
                  "diaPago": 10,
                  "cuotas": [
                    {"numero":1,"fecha":"2026-07-10","saldoCapital":400000,"capital":100000,
                     "interes":10000,"valorCuota":110000,"pagada":true,"fechaPago":"2026-07-10"},
                    {"numero":2,"fecha":"2026-08-10","saldoCapital":300000,"capital":100000,
                     "interes":10000,"valorCuota":110000},
                    {"numero":3,"fecha":"2026-09-10","saldoCapital":200000,"capital":100000,
                     "interes":10000,"valorCuota":110000},
                    {"numero":4,"fecha":"2026-10-10","saldoCapital":100000,"capital":100000,
                     "interes":10000,"valorCuota":110000}
                  ]
                }
                """);
    }

    private MvcResult enviar(MockHttpServletRequestBuilder peticion, String cuerpo)
            throws Exception {
        MvcResult resultado = mvc.perform(auth(peticion)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andReturn();
        assertThat(resultado.getResponse().getStatus())
                .as(resultado.getResponse().getContentAsString())
                .isBetween(200, 299);
        return resultado;
    }

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder peticion) {
        return peticion.header("Authorization", "Bearer " + token);
    }

    private String registrar() throws Exception {
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"ana@ejemplo.co\",\"password\":\"" + PASSWORD
                                + "\",\"nombre\":\"Prueba\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }
}
