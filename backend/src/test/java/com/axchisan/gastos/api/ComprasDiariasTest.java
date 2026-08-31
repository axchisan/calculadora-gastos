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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.UUID;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Las compras del día a día y cómo pesan en el mes.
 *
 * <p>Lo que distingue a este módulo del de gastos es de dónde sale el dinero. Pagar con efectivo
 * o débito lo saca del mes en curso; pagar con crédito no saca nada ahora y lo saca entero
 * cuando vence el corte, uno o dos meses después. Casi todas las comprobaciones de aquí giran
 * sobre esa diferencia.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Compras del día a día")
class ComprasDiariasTest {

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
    private UUID septiembre;
    private UUID octubre;

    @BeforeEach
    void preparar() throws Exception {
        compras.deleteAll();
        tarjetas.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();

        token = registrar();
        agosto = crearMes(2026, 8);
        septiembre = crearMes(2026, 9);
        octubre = crearMes(2026, 10);
    }

    @Test
    void una_compra_en_efectivo_sale_del_dinero_de_hoy() throws Exception {
        comprar(agosto, "Chocorramo", 3600, "ALIMENTACION", "2026-08-05", "EFECTIVO", null);
        comprar(agosto, "Agua", 2200, "ALIMENTACION", "2026-08-05", "EFECTIVO", null);

        mvc.perform(auth(get("/api/meses/" + agosto + "/resumen")))
                .andExpect(jsonPath("$.comprasDelMes").value(5800))
                .andExpect(jsonPath("$.comprasInmediatas").value(5800))
                .andExpect(jsonPath("$.comprasACredito").value(0))
                // El sueldo son 3.000.000; salieron 5.800.
                .andExpect(jsonPath("$.disponibleHoy").value(2994200));
    }

    @Test
    void el_debito_cuenta_igual_que_el_efectivo() throws Exception {
        String debito = crearTarjeta("Débito Nu", "DEBITO", null, null);
        comprar(agosto, "Monsters", 17640, "ANTOJOS", "2026-08-07", "DEBITO", debito);

        mvc.perform(auth(get("/api/meses/" + agosto + "/resumen")))
                .andExpect(jsonPath("$.comprasInmediatas").value(17640))
                .andExpect(jsonPath("$.comprasACredito").value(0));
    }

    /**
     * El caso que justifica todo el módulo: comprar con crédito no cuesta nada este mes y lo
     * cuesta entero el mes en que vence el corte.
     */
    @Test
    void lo_comprado_a_credito_no_toca_el_dinero_de_este_mes() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        comprar(agosto, "Perfume", 100000, "CUIDADO_PERSONAL", "2026-08-14", "CREDITO", nu);

        // Agosto: se compró, pero no salió un peso.
        mvc.perform(auth(get("/api/meses/" + agosto + "/resumen")))
                .andExpect(jsonPath("$.comprasDelMes").value(100000))
                .andExpect(jsonPath("$.comprasInmediatas").value(0))
                .andExpect(jsonPath("$.comprasACredito").value(100000))
                .andExpect(jsonPath("$.disponibleHoy").value(3000000))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(0));

        // Septiembre: aquí sí hay que pagarlo, y ocupa cupo aunque no se haya pagado todavía.
        mvc.perform(auth(get("/api/meses/" + septiembre + "/resumen")))
                .andExpect(jsonPath("$.comprasDelMes").value(0))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(100000))
                .andExpect(jsonPath("$.comprometidoConCuotas").value(100000))
                // Aún no ha salido el dinero: el disponible no se toca.
                .andExpect(jsonPath("$.disponibleHoy").value(3000000))
                // Pero el mes cerrará 100.000 más abajo.
                .andExpect(jsonPath("$.saldoProyectado").value(2900000));
    }

    @Test
    void pasado_el_corte_la_compra_salta_al_mes_siguiente() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        comprar(agosto, "Después del corte", 50000, "ANTOJOS", "2026-08-16", "CREDITO", nu);

        mvc.perform(auth(get("/api/meses/" + septiembre + "/resumen")))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(0));

        mvc.perform(auth(get("/api/meses/" + octubre + "/resumen")))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(50000));
    }

    @Test
    void el_corte_de_un_mes_reune_compras_de_meses_distintos() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        // Del 16 de agosto en adelante y hasta el 15 de septiembre, todo vence en octubre.
        comprar(agosto, "Del 16 de agosto", 30000, "ANTOJOS", "2026-08-16", "CREDITO", nu);
        comprar(septiembre, "Del 10 de septiembre", 20000, "ANTOJOS", "2026-09-10", "CREDITO", nu);
        // Esta ya cae en el corte siguiente.
        comprar(septiembre, "Del 20 de septiembre", 70000, "ANTOJOS", "2026-09-20", "CREDITO", nu);

        mvc.perform(auth(get("/api/cortes/2026-10")))
                .andExpect(jsonPath("$[0].tarjetaNombre").value("Nu"))
                .andExpect(jsonPath("$[0].total").value(50000))
                .andExpect(jsonPath("$[0].pendiente").value(50000))
                .andExpect(jsonPath("$[0].vencimiento").value("2026-10-04"))
                .andExpect(jsonPath("$[0].compras.length()").value(2));

        mvc.perform(auth(get("/api/cortes/2026-11")))
                .andExpect(jsonPath("$[0].total").value(70000));
    }

    @Test
    void saldar_el_corte_lo_convierte_en_dinero_que_ya_salio() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        comprar(agosto, "Perfume", 100000, "CUIDADO_PERSONAL", "2026-08-14", "CREDITO", nu);

        mvc.perform(auth(put("/api/cortes/2026-09/tarjetas/" + nu))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"pagado\":true}"))
                .andExpect(status().isNoContent());

        mvc.perform(auth(get("/api/meses/" + septiembre + "/resumen")))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(0))
                .andExpect(jsonPath("$.cortesTarjetaPagados").value(100000))
                .andExpect(jsonPath("$.disponibleHoy").value(2900000))
                // El total comprometido no cambia por pagarlo: solo cambia de lado.
                .andExpect(jsonPath("$.comprometidoConCuotas").value(100000));
    }

    @Test
    void un_corte_pagado_se_puede_devolver_a_pendiente() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        comprar(agosto, "Perfume", 100000, "CUIDADO_PERSONAL", "2026-08-14", "CREDITO", nu);

        saldarCorte(nu, "2026-09", true);
        saldarCorte(nu, "2026-09", false);

        mvc.perform(auth(get("/api/meses/" + septiembre + "/resumen")))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(100000))
                .andExpect(jsonPath("$.cortesTarjetaPagados").value(0));
    }

    @Test
    void las_compras_entran_en_la_distribucion_por_categoria() throws Exception {
        comprar(agosto, "Chocorramo", 3600, "ANTOJOS", "2026-08-05", "EFECTIVO", null);
        comprar(agosto, "Transmiapp", 2000, "TRANSPORTE", "2026-08-06", "EFECTIVO", null);

        // Ordenadas de mayor a menor, que es como las dibuja la gráfica.
        mvc.perform(auth(get("/api/meses/" + agosto + "/resumen")))
                .andExpect(jsonPath("$.porCategoria.length()").value(2))
                .andExpect(jsonPath("$.porCategoria[0].categoria").value("ANTOJOS"))
                .andExpect(jsonPath("$.porCategoria[0].total").value(3600))
                .andExpect(jsonPath("$.porCategoria[1].categoria").value("TRANSPORTE"))
                .andExpect(jsonPath("$.porCategoria[1].total").value(2000));
    }

    @Test
    void el_listado_del_mes_trae_los_totales_y_el_ritmo_por_dia() throws Exception {
        comprar(agosto, "Agua", 2200, "ALIMENTACION", "2026-08-05", "EFECTIVO", null);
        comprar(agosto, "Chocorramo", 3600, "ANTOJOS", "2026-08-05", "EFECTIVO", null);
        comprar(agosto, "Bebidas", 8500, "ANTOJOS", "2026-08-09", "EFECTIVO", null);

        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(14300))
                .andExpect(jsonPath("$.compras.length()").value(3))
                .andExpect(jsonPath("$.porDia.length()").value(2))
                .andExpect(jsonPath("$.porDia[0].fecha").value("2026-08-05"))
                .andExpect(jsonPath("$.porDia[0].total").value(5800))
                .andExpect(jsonPath("$.porDia[1].total").value(8500));
    }

    @Test
    void una_compra_se_puede_corregir_y_eliminar() throws Exception {
        String id = comprar(agosto, "Chocoramo", 3000, "OTRO", "2026-08-05", "EFECTIVO", null);

        mvc.perform(auth(patch("/api/compras/" + id))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"descripcion\":\"Chocorramo\",\"monto\":3600,"
                                + "\"categoria\":\"ANTOJOS\"}"))
                .andExpect(jsonPath("$.descripcion").value("Chocorramo"))
                .andExpect(jsonPath("$.monto").value(3600))
                .andExpect(jsonPath("$.categoria").value("ANTOJOS"));

        mvc.perform(auth(delete("/api/compras/" + id))).andExpect(status().isNoContent());

        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(0));
    }

    /**
     * Cambiar la fecha recalcula el mes de pago. Con crédito no es un detalle cosmético:
     * corrige de qué mes sale el dinero.
     */
    @Test
    void corregir_la_fecha_recoloca_el_mes_de_pago() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        String id = comprar(agosto, "Perfume", 100000, "CUIDADO_PERSONAL", "2026-08-14",
                "CREDITO", nu);

        mvc.perform(auth(patch("/api/compras/" + id))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fecha\":\"2026-08-20\"}"))
                .andExpect(jsonPath("$.periodoPago").value("2026-10"));

        mvc.perform(auth(get("/api/meses/" + septiembre + "/resumen")))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(0));
        mvc.perform(auth(get("/api/meses/" + octubre + "/resumen")))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(100000));
    }

    /**
     * Recargar la tarjeta del bus cuesta una comisión fija por operación, así que recargar de a
     * poco sale más caro. Ese cargo se perdía: el gasto de transporte reflejaba solo los pasajes.
     */
    @Test
    void abonar_al_transporte_apunta_la_comision_de_recarga() throws Exception {
        // Se prepara el transporte del mes con su comisión.
        mvc.perform(auth(patch("/api/meses/" + agosto + "/transporte/configuracion"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"valorPasaje\":3550,\"comisionRecarga\":230}"))
                .andExpect(status().isOk());

        String transporte = idDelGastoDeTransporte(agosto);

        mvc.perform(auth(post("/api/gastos/" + transporte + "/abonar"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"importe\":20000,\"fecha\":\"2026-08-10\"}"))
                .andExpect(status().isOk());

        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(230))
                .andExpect(jsonPath("$.compras[0].descripcion").value("Comisión de recarga"))
                .andExpect(jsonPath("$.compras[0].categoria").value("COMISIONES"))
                .andExpect(jsonPath("$.compras[0].fecha").value("2026-08-10"));
    }

    @Test
    void cada_recarga_apunta_su_propia_comision() throws Exception {
        mvc.perform(auth(patch("/api/meses/" + agosto + "/transporte/configuracion"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"valorPasaje\":3550,\"comisionRecarga\":230}"))
                .andExpect(status().isOk());

        String transporte = idDelGastoDeTransporte(agosto);
        for (final String dia : new String[] {"2026-08-05", "2026-08-12", "2026-08-19"}) {
            mvc.perform(auth(post("/api/gastos/" + transporte + "/abonar"))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"importe\":10000,\"fecha\":\"" + dia + "\"}"))
                    .andExpect(status().isOk());
        }

        // Tres recargas, tres comisiones: es justo lo que hace visible que fraccionar sale caro.
        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(690))
                .andExpect(jsonPath("$.compras.length()").value(3));
    }

    @Test
    void sin_comision_configurada_no_se_apunta_nada() throws Exception {
        // Con tarifa pero sin comisión: hay gasto de transporte al que abonar, y nada más.
        mvc.perform(auth(patch("/api/meses/" + agosto + "/transporte/configuracion"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"valorPasaje\":3550}"))
                .andExpect(status().isOk());

        String transporte = idDelGastoDeTransporte(agosto);

        mvc.perform(auth(post("/api/gastos/" + transporte + "/abonar"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"importe\":20000}"))
                .andExpect(status().isOk());

        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void abonar_a_un_gasto_normal_no_apunta_comision() throws Exception {
        mvc.perform(auth(patch("/api/meses/" + agosto + "/transporte/configuracion"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"valorPasaje\":3550,\"comisionRecarga\":230}"))
                .andExpect(status().isOk());

        String respuesta = mvc.perform(auth(post("/api/meses/" + agosto + "/gastos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Celular\",\"categoria\":\"SERVICIOS\","
                                + "\"monto\":100000}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String celular = json.readTree(respuesta).get("id").asText();

        mvc.perform(auth(post("/api/gastos/" + celular + "/abonar"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"importe\":50000}"))
                .andExpect(status().isOk());

        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(0));
    }

    // --- lo que no se admite ---

    @Test
    void no_se_puede_pagar_a_credito_sin_tarjeta() throws Exception {
        mvc.perform(auth(post("/api/meses/" + agosto + "/compras"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoCompra("Algo", 1000, "OTRO", "2026-08-05",
                                "CREDITO", null)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("peticion_invalida"));
    }

    @Test
    void una_tarjeta_de_debito_no_sirve_para_pagar_a_credito() throws Exception {
        String debito = crearTarjeta("Débito", "DEBITO", null, null);

        mvc.perform(auth(post("/api/meses/" + agosto + "/compras"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoCompra("Algo", 1000, "OTRO", "2026-08-05",
                                "CREDITO", debito)))
                .andExpect(status().isBadRequest());
    }

    /**
     * El mes presupuestal no coincide con el del calendario: quien cobra el 28 imputa a
     * septiembre lo que compra desde esa fecha. Exigir que la fecha cayera dentro del mes
     * obligaba a mentir sobre el día de la compra.
     */
    @Test
    void una_compra_de_fin_del_mes_pasado_se_imputa_a_este() throws Exception {
        comprar(septiembre, "Dunkins", 69000, "ANTOJOS", "2026-08-28", "EFECTIVO", null);

        mvc.perform(auth(get("/api/meses/" + septiembre + "/compras")))
                .andExpect(jsonPath("$.total").value(69000))
                .andExpect(jsonPath("$.compras[0].fecha").value("2026-08-28"));

        // Y no cuenta en agosto, que es el mes en que se compró pero no al que se imputa.
        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void con_credito_la_fecha_real_sigue_decidiendo_el_mes_de_pago() throws Exception {
        String nu = crearTarjeta("Nu", "CREDITO", 15, 4);
        // Comprada el 28 de agosto pero apuntada en septiembre: pasado el corte del 15, se paga
        // en octubre. Mentir sobre la fecha lo habría mandado a noviembre.
        comprar(septiembre, "Perfume", 100000, "CUIDADO_PERSONAL", "2026-08-28", "CREDITO", nu);

        mvc.perform(auth(get("/api/meses/" + octubre + "/resumen")))
                .andExpect(jsonPath("$.cortesTarjetaPendientes").value(100000));
    }

    @Test
    void una_fecha_de_hace_meses_se_sigue_rechazando() throws Exception {
        // El límite existe para cazar un mes o un año tecleado mal, y eso no cambia.
        mvc.perform(auth(post("/api/meses/" + octubre + "/compras"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoCompra("De agosto", 1000, "OTRO", "2026-08-03",
                                "EFECTIVO", null)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.mensaje").value(containsString("2026-10")));
    }

    @Test
    void una_compra_del_mes_siguiente_no_cabe() throws Exception {
        mvc.perform(auth(post("/api/meses/" + agosto + "/compras"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoCompra("De septiembre", 1000, "OTRO", "2026-09-03",
                                "EFECTIVO", null)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.mensaje").value(containsString("2026-08")));
    }

    @Test
    void los_importes_conservan_los_centavos() throws Exception {
        // Un plan de pagos o un extracto traen decimales; redondearlos descuadra las cuentas.
        comprar2(agosto, "Cuota", "192729.03", "OTRO", "2026-08-05", "EFECTIVO", null);

        mvc.perform(auth(get("/api/meses/" + agosto + "/compras")))
                .andExpect(jsonPath("$.total").value(192729.03))
                .andExpect(jsonPath("$.compras[0].monto").value(192729.03));
    }

    @Test
    void una_tarjeta_de_credito_sin_ciclo_no_se_admite() throws Exception {
        mvc.perform(auth(post("/api/tarjetas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Sin ciclo\",\"tipo\":\"CREDITO\"}"))
                .andExpect(status().isBadRequest());
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

    private String crearTarjeta(String nombre, String tipo, Integer corte, Integer pago)
            throws Exception {
        String ciclo = corte == null ? ""
                : ",\"diaCorte\":" + corte + ",\"diaPago\":" + pago;
        String respuesta = mvc.perform(auth(post("/api/tarjetas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"" + nombre + "\",\"tipo\":\"" + tipo + "\""
                                + ciclo + "}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private String comprar(UUID mesId, String descripcion, int monto, String categoria,
                           String fecha, String medio, String tarjetaId) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/meses/" + mesId + "/compras"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoCompra(descripcion, monto, categoria, fecha, medio,
                                tarjetaId)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private void comprar2(UUID mesId, String descripcion, String monto, String categoria,
                          String fecha, String medio, String tarjetaId) throws Exception {
        mvc.perform(auth(post("/api/meses/" + mesId + "/compras"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"descripcion\":\"" + descripcion + "\",\"monto\":" + monto
                                + ",\"categoria\":\"" + categoria + "\",\"fecha\":\"" + fecha
                                + "\",\"medio\":\"" + medio + "\"}"))
                .andExpect(status().isCreated());
    }

    private void saldarCorte(String tarjetaId, String periodo, boolean pagado) throws Exception {
        mvc.perform(auth(put("/api/cortes/" + periodo + "/tarjetas/" + tarjetaId))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"pagado\":" + pagado + "}"))
                .andExpect(status().isNoContent());
    }

    /** El gasto que el sistema genera con el cálculo del transporte. */
    private String idDelGastoDeTransporte(UUID mesId) throws Exception {
        String respuesta = mvc.perform(auth(get("/api/meses/" + mesId + "/gastos")))
                .andReturn().getResponse().getContentAsString();

        for (var gasto : json.readTree(respuesta)) {
            if ("TRANSPORTE".equals(gasto.get("origen").asText())) {
                return gasto.get("id").asText();
            }
        }
        throw new AssertionError("el mes no tiene gasto de transporte");
    }

    private static String cuerpoCompra(String descripcion, int monto, String categoria,
                                       String fecha, String medio, String tarjetaId) {
        return "{\"descripcion\":\"" + descripcion + "\",\"monto\":" + monto
                + ",\"categoria\":\"" + categoria + "\",\"fecha\":\"" + fecha + "\""
                + ",\"medio\":\"" + medio + "\""
                + (tarjetaId == null ? "" : ",\"tarjetaId\":\"" + tarjetaId + "\"")
                + "}";
    }
}
