package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.CuentaRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
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

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Los saldos de «Mis cuentas» siguen a lo que se apunta después de anotarlos. Cifras inventadas.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Saldos que siguen a lo apuntado")
class SaldosQueSiguenTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;
    @Autowired private MesPresupuestalRepository meses;
    @Autowired private CompraRepository compras;
    @Autowired private CuentaRepository cuentas;
    @Autowired private DeudaRepository deudas;

    private String token;
    private String mes;
    private String banco;
    private String efectivo;
    private String billetera;
    private final String hoy = LocalDate.now().toString();

    @BeforeEach
    void preparar() throws Exception {
        compras.deleteAll();
        deudas.deleteAll();
        cuentas.deleteAll();
        refrescos.deleteAll();
        meses.deleteAll();
        usuarios.deleteAll();
        token = registrar();
        YearMonth periodo = ServicioInicio.periodoDe(LocalDate.now());
        mes = id(enviar(post("/api/meses"), "{\"anio\":" + periodo.getYear() + ",\"mes\":"
                + periodo.getMonthValue() + ",\"ingresoBase\":0,\"copiarPlantillas\":false}"));
        banco = cuenta("Banco", "BANCO", 500000);
        billetera = cuenta("Billetera", "BILLETERA", 5000);
        efectivo = cuenta("Efectivo", "EFECTIVO", 20000);
    }

    @Test
    void una_compra_en_efectivo_baja_el_efectivo() throws Exception {
        compra("Bebida", 9000, "EFECTIVO");
        assertThat(saldo(efectivo)).isEqualByComparingTo("11000");
        assertThat(saldo(banco)).isEqualByComparingTo("500000");
        JsonNode e = cuentaJson(efectivo);
        assertThat(e.get("saldoAnotado").decimalValue()).isEqualByComparingTo("20000");
        assertThat(e.get("cambio").decimalValue()).isEqualByComparingTo("-9000");
    }

    @Test
    void lo_demas_mueve_la_cuenta_principal() throws Exception {
        compra("Mercado", 12000, "DEBITO");
        enviar(post("/api/meses/" + mes + "/ingresos"), """
                {"concepto":"Apoyo","monto":100000,"fecha":"%s","recibido":true,"tipo":"FAMILIA"}
                """.formatted(hoy));
        // El saldo con que abre el mes es plata que ya estaba en las cuentas.
        enviar(post("/api/meses/" + mes + "/ingresos"), """
                {"concepto":"Saldo al cierre","monto":300000,"fecha":"%s","recibido":true,
                 "tipo":"SALDO"}
                """.formatted(hoy));
        // Un ingreso que aún no llega no mueve nada.
        enviar(post("/api/meses/" + mes + "/ingresos"), """
                {"concepto":"Bono","monto":70000,"fecha":"%s","recibido":false}
                """.formatted(hoy));
        String gasto = id(enviar(post("/api/meses/" + mes + "/gastos"),
                "{\"nombre\":\"Luz\",\"categoria\":\"SERVICIOS\",\"monto\":40000}"));
        enviar(post("/api/gastos/" + gasto + "/pagar"), "{\"fecha\":\"" + hoy + "\"}");
        String deuda = id(enviar(post("/api/deudas"), """
                {"acreedor":"Tía","tipo":"FAMILIAR","montoOriginal":80000,"fechaInicio":"2026-07-01"}
                """));
        enviar(post("/api/deudas/" + deuda + "/abonos"),
                "{\"monto\":30000,\"fecha\":\"" + hoy + "\",\"mesId\":\"" + mes + "\"}");
        compra("Zapatos a crédito", 90000, "CREDITO");

        // 500.000 − 12.000 + 100.000 − 40.000 − 30.000
        assertThat(saldo(banco)).isEqualByComparingTo("518000");
        assertThat(saldo(billetera)).isEqualByComparingTo("5000");
        assertThat(saldo(efectivo)).isEqualByComparingTo("20000");
    }

    @Test
    void al_anotar_el_saldo_real_se_vuelve_a_cuadrar() throws Exception {
        compra("Mercado", 12000, "DEBITO");
        compra("Bebida", 9000, "EFECTIVO");
        assertThat(saldo(banco)).isEqualByComparingTo("488000");

        JsonNode anotada = json.readTree(enviar(patch("/api/cuentas/" + banco),
                "{\"saldo\":487500}").getResponse().getContentAsString());
        assertThat(anotada.get("saldo").decimalValue()).isEqualByComparingTo("487500");
        assertThat(anotada.get("cambio").decimalValue()).isEqualByComparingTo("0");
        assertThat(saldo(banco)).isEqualByComparingTo("487500");
        // El efectivo no se volvió a anotar: sigue descontando la bebida.
        assertThat(saldo(efectivo)).isEqualByComparingTo("11000");

        compra("Pan", 3000, "DEBITO");
        assertThat(saldo(banco)).isEqualByComparingTo("484500");
    }

    @Test
    void inicio_muestra_los_saldos_al_dia() throws Exception {
        compra("Bebida", 9000, "EFECTIVO");
        JsonNode inicio = json.readTree(mvc.perform(auth(get("/api/inicio")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        BigDecimal total = BigDecimal.ZERO;
        for (JsonNode c : inicio.get("cuentas")) {
            total = total.add(c.get("saldo").decimalValue());
        }
        assertThat(total).isEqualByComparingTo("516000");
    }

    // --- ayudantes ---

    private void compra(String descripcion, int monto, String medio) throws Exception {
        String tarjeta = "";
        if (medio.equals("CREDITO")) {
            tarjeta = ",\"tarjetaId\":\"" + id(enviar(post("/api/tarjetas"), """
                    {"nombre":"Visa","tipo":"CREDITO","diaCorte":15,"diaPago":5}
                    """)) + "\"";
        }
        enviar(post("/api/meses/" + mes + "/compras"), "{\"descripcion\":\"" + descripcion
                + "\",\"monto\":" + monto + ",\"categoria\":\"OTRO\",\"fecha\":\"" + hoy
                + "\",\"medio\":\"" + medio + "\"" + tarjeta + "}");
    }

    private String cuenta(String nombre, String tipo, int saldo) throws Exception {
        return id(enviar(post("/api/cuentas"), "{\"nombre\":\"" + nombre + "\",\"tipo\":\""
                + tipo + "\",\"saldo\":" + saldo + "}"));
    }

    private BigDecimal saldo(String cuentaId) throws Exception {
        return cuentaJson(cuentaId).get("saldo").decimalValue();
    }

    private JsonNode cuentaJson(String cuentaId) throws Exception {
        JsonNode lista = json.readTree(mvc.perform(auth(get("/api/cuentas")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        for (JsonNode c : lista) {
            if (c.get("id").asText().equals(cuentaId)) {
                return c;
            }
        }
        throw new AssertionError("No está la cuenta " + cuentaId);
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
        String respuesta = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"ana@ejemplo.co\",\"password\":\"" + PASSWORD
                                + "\",\"nombre\":\"Prueba\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("accessToken").asText();
    }
}
