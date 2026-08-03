package com.axchisan.gastos.api;

import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MetaAhorroRepository;
import com.axchisan.gastos.repositorio.PlantillaGastoRepository;
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

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Cómo pesan las deudas en la estimación del mes.
 *
 * <p>Una deuda con cuota pactada seguirá pidiendo dinero aunque todavía no se haya abonado
 * nada. Contarla es lo que permite ver el cupo real del sueldo antes de que el mes ocurra.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Cuotas de deuda en la estimación")
class CuotasDeudaTest {

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

    @Test
    void una_deuda_con_cuota_ocupa_cupo_aunque_no_se_haya_abonado_nada() throws Exception {
        UUID mesId = crearMes();
        crearDeuda("Tarjeta", 2000000, 200000);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.abonosDeuda").value(0))
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(200000))
                // El transporte del mes sale en cero al no haber tarifa configurada.
                .andExpect(jsonPath("$.comprometidoConCuotas").value(200000));
    }

    /**
     * Sin cuota no hay nada que proyectar: no se puede adivinar cuánto se piensa abonar. La
     * aplicación lo cuenta aparte para poder avisar en lugar de ignorarlas en silencio.
     */
    @Test
    void una_deuda_sin_cuota_no_se_proyecta_pero_se_avisa() throws Exception {
        UUID mesId = crearMes();
        crearDeudaSinCuota("Mamá", 400000);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(0))
                .andExpect(jsonPath("$.deudasSinCuota").value(1))
                .andExpect(jsonPath("$.deudaTotal").value(400000));
    }

    @Test
    void abonar_reduce_lo_que_queda_de_la_cuota() throws Exception {
        UUID mesId = crearMes();
        String deudaId = crearDeuda("Tarjeta", 2000000, 200000);

        abonar(deudaId, 50000, mesId);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.abonosDeuda").value(50000))
                // Quedan 150.000 de la cuota de este mes
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(150000))
                // El total sigue siendo la cuota: 50.000 pagados más 150.000 por pagar
                .andExpect(jsonPath("$.comprometidoConCuotas").value(200000));
    }

    @Test
    void cubrir_la_cuota_completa_deja_de_reservar_cupo() throws Exception {
        UUID mesId = crearMes();
        String deudaId = crearDeuda("Tarjeta", 2000000, 200000);

        abonar(deudaId, 200000, mesId);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(0))
                .andExpect(jsonPath("$.comprometidoConCuotas").value(200000));
    }

    /** Abonar de más no debe dejar la cuota pendiente en negativo. */
    @Test
    void abonar_por_encima_de_la_cuota_no_resta_cupo() throws Exception {
        UUID mesId = crearMes();
        String deudaId = crearDeuda("Tarjeta", 2000000, 200000);

        abonar(deudaId, 500000, mesId);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(0))
                .andExpect(jsonPath("$.comprometidoConCuotas").value(500000));
    }

    /** Una deuda casi saldada no puede reclamar más de lo que queda debiendo. */
    @Test
    void la_cuota_nunca_supera_el_saldo_pendiente() throws Exception {
        UUID mesId = crearMes();
        // Debe 50.000 pero la cuota pactada era de 200.000.
        crearDeuda("Monet", 50000, 200000);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(50000));
    }

    @Test
    void una_deuda_saldada_deja_de_pesar() throws Exception {
        UUID mesId = crearMes();
        String deudaId = crearDeuda("Amigo", 100000, 50000);

        abonar(deudaId, 100000, mesId);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(0))
                .andExpect(jsonPath("$.deudaTotal").value(0));
    }

    @Test
    void varias_deudas_suman_sus_cuotas() throws Exception {
        UUID mesId = crearMes();
        crearDeuda("Tarjeta", 2000000, 200000);
        crearDeuda("Mamá", 400000, 100000);
        crearDeudaSinCuota("Lexy", 300000);

        mvc.perform(auth(get("/api/meses/" + mesId + "/resumen")))
                .andExpect(jsonPath("$.cuotasDeudaPendientes").value(300000))
                .andExpect(jsonPath("$.deudasSinCuota").value(1))
                .andExpect(jsonPath("$.deudaTotal").value(2700000));
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
        String respuesta = mvc.perform(auth(post("/api/meses"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoMes()))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(json.readTree(respuesta).get("id").asText());
    }

    private String crearDeuda(String acreedor, int monto, int cuota) throws Exception {
        return crear(cuerpoDeuda(acreedor, monto, cuota));
    }

    private String crearDeudaSinCuota(String acreedor, int monto) throws Exception {
        return crear(cuerpoDeudaSinCuota(acreedor, monto));
    }

    private String crear(String cuerpo) throws Exception {
        String respuesta = mvc.perform(auth(post("/api/deudas"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(respuesta).get("id").asText();
    }

    private void abonar(String deudaId, int monto, UUID mesId) throws Exception {
        mvc.perform(auth(post("/api/deudas/" + deudaId + "/abonos"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoAbono(monto, mesId)))
                .andExpect(status().isCreated());
    }

    private static String cuerpoRegistro() {
        return "{\"email\":\"duvan@axchisan.com\",\"password\":\"" + PASSWORD
                + "\",\"nombre\":\"Duvan\"}";
    }

    private static String cuerpoMes() {
        return "{\"anio\":2026,\"mes\":9,\"ingresoBase\":3174000}";
    }

    private static String cuerpoDeuda(String acreedor, int monto, int cuota) {
        return "{\"acreedor\":\"" + acreedor + "\",\"tipo\":\"TARJETA_CREDITO\","
                + "\"montoOriginal\":" + monto + ",\"cuotaSugerida\":" + cuota + "}";
    }

    private static String cuerpoDeudaSinCuota(String acreedor, int monto) {
        return "{\"acreedor\":\"" + acreedor + "\",\"tipo\":\"FAMILIAR\","
                + "\"montoOriginal\":" + monto + "}";
    }

    private static String cuerpoAbono(int monto, UUID mesId) {
        return "{\"monto\":" + monto + ",\"mesId\":\"" + mesId + "\"}";
    }
}
