package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.CreditoRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MetaAhorroRepository;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.TarjetaRepository;
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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * La lista unificada de movimientos del mes, el tipo de los ingresos y la categoría Mascota.
 * Todas las cifras son inventadas.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Movimientos del mes")
class MovimientosTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private CompraRepository compras;
    @Autowired private TarjetaRepository tarjetas;
    @Autowired private DeudaRepository deudas;
    @Autowired private CreditoRepository creditos;
    @Autowired private MetaAhorroRepository metas;

    private String token;
    private UUID agosto;

    @BeforeEach
    void preparar() throws Exception {
        compras.deleteAll();
        tarjetas.deleteAll();
        deudas.deleteAll();
        creditos.deleteAll();
        metas.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();
        agosto = crearMes(2026, 8, 1000000);
    }

    @Test
    void junta_todo_y_suma_exactamente_el_disponible_del_mes() throws Exception {
        enviar(post("/api/meses/" + agosto + "/ingresos"), """
                {"concepto":"Préstamo de un amigo","monto":50000,"fecha":"2026-08-03",
                 "recibido":true,"tipo":"PRESTAMO","notas":"Se devuelve en septiembre"}
                """);
        enviar(post("/api/meses/" + agosto + "/ingresos"), """
                {"concepto":"Bono por cobrar","monto":30000,"fecha":"2026-08-20","recibido":false}
                """);
        UUID arriendo = crearGasto("Arriendo", 400000);
        enviar(post("/api/gastos/" + arriendo + "/pagar"), "{\"fecha\":\"2026-08-05\"}");
        UUID luz = crearGasto("Luz", 60000);
        enviar(post("/api/gastos/" + luz + "/corregir-pago"),
                "{\"montoPagado\":20000,\"fecha\":\"2026-08-10\"}");
        crearGasto("Internet", 70000);
        enviar(post("/api/meses/" + agosto + "/compras"), """
                {"descripcion":"Comida del perro","monto":25000,"categoria":"MASCOTA",
                 "fecha":"2026-08-07","medio":"EFECTIVO"}
                """);
        String tarjeta = id(enviar(post("/api/tarjetas"), """
                {"nombre":"Visa","tipo":"CREDITO","diaCorte":15,"diaPago":5}
                """));
        enviar(post("/api/meses/" + agosto + "/compras"), """
                {"descripcion":"Zapatos","monto":90000,"categoria":"ROPA","fecha":"2026-08-08",
                 "medio":"CREDITO","tarjetaId":"%s"}
                """.formatted(tarjeta));
        String deuda = id(enviar(post("/api/deudas"), """
                {"acreedor":"Tía","tipo":"FAMILIAR","montoOriginal":80000,
                 "fechaInicio":"2026-07-01"}
                """));
        enviar(post("/api/deudas/" + deuda + "/abonos"),
                "{\"monto\":30000,\"fecha\":\"2026-08-12\",\"mesId\":\"" + agosto + "\"}");
        String meta = id(enviar(post("/api/ahorro/metas"), """
                {"nombre":"Viaje","tipoAsignacion":"MONTO_FIJO","valor":100000}
                """));
        enviar(post("/api/ahorro/metas/" + meta + "/movimientos"),
                "{\"tipo\":\"APORTE\",\"monto\":40000,\"fecha\":\"2026-08-15\",\"mesId\":\""
                        + agosto + "\"}");

        JsonNode m = leer();
        JsonNode resumen = json.readTree(mvc.perform(auth(get("/api/meses/" + agosto
                + "/resumen"))).andReturn().getResponse().getContentAsString());

        // Lo que suma la lista (sin la compra a crédito) es el disponible del mes.
        BigDecimal suma = BigDecimal.ZERO;
        for (JsonNode mov : m.get("movimientos")) {
            if (mov.get("cuenta").asBoolean()) {
                suma = suma.add(mov.get("monto").decimalValue());
            }
        }
        assertThat(suma).isEqualByComparingTo(resumen.get("disponibleHoy").decimalValue());
        assertThat(m.get("queda").decimalValue())
                .isEqualByComparingTo(resumen.get("disponibleHoy").decimalValue());
        assertThat(m.get("entro").decimalValue()).isEqualByComparingTo("1050000");

        List<String> titulos = new ArrayList<>();
        m.get("movimientos").forEach(x -> titulos.add(x.get("titulo").asText()));
        assertThat(titulos).containsExactly(
                "Ahorro · Viaje", "Pago a Tía", "Luz", "Zapatos", "Comida del perro",
                "Arriendo", "Préstamo de un amigo", "Sueldo del mes");
        // El ingreso sin cobrar no está: aún no entró.
        assertThat(titulos).doesNotContain("Bono por cobrar");

        JsonNode prestamo = buscar(m, "Préstamo de un amigo");
        assertThat(prestamo.get("tipo").asText()).isEqualTo("INGRESO");
        assertThat(prestamo.get("categoria").asText()).isEqualTo("PRESTAMO");
        assertThat(prestamo.get("etiqueta").asText()).isEqualTo("PRESTAMO");
        assertThat(prestamo.get("notas").asText()).isEqualTo("Se devuelve en septiembre");

        JsonNode zapatos = buscar(m, "Zapatos");
        assertThat(zapatos.get("cuenta").asBoolean()).isFalse();
        assertThat(zapatos.get("etiqueta").asText()).isEqualTo("CREDITO");
        assertThat(zapatos.get("detalle").asText()).isEqualTo("Visa · se paga el 5 sep");

        JsonNode luzPagada = buscar(m, "Luz");
        assertThat(luzPagada.get("monto").decimalValue()).isEqualByComparingTo("-20000");
        assertThat(luzPagada.get("detalle").asText()).isEqualTo("Pagado en parte");

        assertThat(buscar(m, "Comida del perro").get("categoria").asText()).isEqualTo("MASCOTA");
        assertThat(buscar(m, "Sueldo del mes").get("fecha").asText()).isEqualTo("2026-07-28");

        // Lo que falta: la luz (40.000) y el internet; el arriendo ya se pagó.
        JsonNode porPagar = m.get("porPagar");
        assertThat(porPagar).hasSize(2);
        List<String> pendientes = new ArrayList<>();
        porPagar.forEach(p -> pendientes.add(p.get("nombre").asText() + " "
                + p.get("pendiente").decimalValue().stripTrailingZeros().toPlainString()));
        assertThat(pendientes).containsExactlyInAnyOrder("Internet 70000", "Luz 40000");
    }

    @Test
    void las_cuotas_de_credito_pagadas_salen_en_su_mes_calendario() throws Exception {
        enviar(post("/api/creditos"), """
                {"entidad":"Banco Uno","montoOriginal":300000,"tasaEa":30.0,"plazoCuotas":2,
                 "cuotas":[
                   {"numero":1,"fecha":"2026-08-02","saldoCapital":300000,"capital":150000,
                    "interes":5000,"valorCuota":155000,"pagada":true,"fechaPago":"2026-08-02"},
                   {"numero":2,"fecha":"2026-09-02","saldoCapital":150000,"capital":150000,
                    "interes":2500,"valorCuota":152500}
                 ]}
                """);

        JsonNode cuota = buscar(leer(), "Cuota 1 · Banco Uno");
        assertThat(cuota.get("tipo").asText()).isEqualTo("CUOTA");
        assertThat(cuota.get("monto").decimalValue()).isEqualByComparingTo("-155000");
        assertThat(cuota.get("detalle").asText()).isEqualTo("Crédito · cuota 1 de 2");
    }

    @Test
    void un_ingreso_se_puede_corregir_y_clasificar() throws Exception {
        String ingreso = id(enviar(post("/api/meses/" + agosto + "/ingresos"), """
                {"concepto":"Pago","monto":10000,"fecha":"2026-08-03","recibido":true}
                """));

        mvc.perform(auth(patch("/api/meses/ingresos/" + ingreso))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"concepto":"Diseño de un logo","monto":15000,"tipo":"TRABAJO",
                                 "notas":"Para un vecino"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.concepto").value("Diseño de un logo"))
                .andExpect(jsonPath("$.monto").value(15000))
                .andExpect(jsonPath("$.tipo").value("TRABAJO"))
                .andExpect(jsonPath("$.notas").value("Para un vecino"));

        mvc.perform(auth(get("/api/meses/" + agosto + "/ingresos")))
                .andExpect(jsonPath("$[0].tipo").value("TRABAJO"));
    }

    @Test
    void sin_tipo_un_ingreso_queda_como_otro() throws Exception {
        enviar(post("/api/meses/" + agosto + "/ingresos"),
                "{\"concepto\":\"Algo\",\"monto\":1000,\"recibido\":true}");
        mvc.perform(auth(get("/api/meses/" + agosto + "/ingresos")))
                .andExpect(jsonPath("$[0].tipo").value("OTRO"));
    }

    @Test
    void la_categoria_mascota_vale_en_gastos_y_plantillas() throws Exception {
        enviar(post("/api/meses/" + agosto + "/gastos"),
                "{\"nombre\":\"Concentrado\",\"categoria\":\"MASCOTA\",\"monto\":45000}");
        enviar(post("/api/plantillas"),
                "{\"nombre\":\"Veterinaria\",\"categoria\":\"MASCOTA\",\"montoDefault\":30000}");
    }

    @Test
    void otro_usuario_no_ve_los_movimientos() throws Exception {
        String propio = token;
        token = registrar("beto@ejemplo.co");
        mvc.perform(auth(get("/api/meses/" + agosto + "/movimientos")))
                .andExpect(status().isNotFound());
        token = propio;
    }

    // --- ayudas ---

    private JsonNode leer() throws Exception {
        return json.readTree(mvc.perform(auth(get("/api/meses/" + agosto + "/movimientos")))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString());
    }

    private static JsonNode buscar(JsonNode m, String titulo) {
        for (JsonNode mov : m.get("movimientos")) {
            if (mov.get("titulo").asText().equals(titulo)) {
                return mov;
            }
        }
        throw new AssertionError("No está: " + titulo);
    }

    private UUID crearMes(int anio, int mes, int sueldo) throws Exception {
        return UUID.fromString(id(enviar(post("/api/meses"), "{\"anio\":" + anio + ",\"mes\":"
                + mes + ",\"ingresoBase\":" + sueldo + ",\"copiarPlantillas\":false}")));
    }

    private UUID crearGasto(String nombre, int monto) throws Exception {
        return UUID.fromString(id(enviar(post("/api/meses/" + agosto + "/gastos"),
                "{\"nombre\":\"" + nombre + "\",\"categoria\":\"SERVICIOS\",\"monto\":" + monto
                        + "}")));
    }

    private String id(MvcResult resultado) throws Exception {
        return json.readTree(resultado.getResponse().getContentAsString()).get("id").asText();
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
        return registrar("ana@ejemplo.co");
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
