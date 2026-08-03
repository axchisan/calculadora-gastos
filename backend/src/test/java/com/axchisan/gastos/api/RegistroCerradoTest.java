package com.axchisan.gastos.api;

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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Comprueba el cierre del registro.
 *
 * <p>Es una aplicación de uso personal: la primera cuenta se crea sola cuando la base está
 * vacía y, a partir de ahí, no se admiten más. Así no hace falta acordarse de desactivar nada
 * tras el primer arranque.
 *
 * <p>Se sobrescribe {@code app.registro.abierto} a falso porque el perfil de pruebas lo deja
 * abierto para que el resto de casos puedan crear varias cuentas.
 */
@SpringBootTest(properties = "app.registro.abierto=false")
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("Registro cerrado")
class RegistroCerradoTest {

    private static final String PASSWORD = "unaClaveSegura123";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UsuarioRepository usuarios;
    @Autowired private RefreshTokenRepository refrescos;

    @BeforeEach
    void limpiar() {
        refrescos.deleteAll();
        usuarios.deleteAll();
    }

    @Test
    void con_la_base_vacia_se_admite_la_primera_cuenta() throws Exception {
        mvc.perform(get("/api/auth/registro-abierto"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.abierto").value(true));

        mvc.perform(registro("duvan@axchisan.com")).andExpect(status().isCreated());
    }

    @Test
    void tras_la_primera_cuenta_el_registro_se_cierra_solo() throws Exception {
        mvc.perform(registro("duvan@axchisan.com")).andExpect(status().isCreated());

        mvc.perform(get("/api/auth/registro-abierto"))
                .andExpect(jsonPath("$.abierto").value(false));

        mvc.perform(registro("intruso@axchisan.com"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("registro_cerrado"));
    }

    @Test
    void el_estado_del_registro_se_consulta_sin_sesion() throws Exception {
        // La pantalla de acceso lo consulta antes de que exista ninguna sesión, para decidir si
        // muestra la opción de crear cuenta.
        mvc.perform(get("/api/auth/registro-abierto")).andExpect(status().isOk());
    }

    @Test
    void el_dueno_de_la_cuenta_sigue_pudiendo_entrar() throws Exception {
        mvc.perform(registro("duvan@axchisan.com")).andExpect(status().isCreated());

        mvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"duvan@axchisan.com","password":"%s"}"""
                                .formatted(PASSWORD)))
                .andExpect(status().isOk());
    }

    private org.springframework.test.web.servlet.RequestBuilder registro(String email) {
        return post("/api/auth/registro")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"email":"%s","password":"%s","nombre":"Duvan"}"""
                        .formatted(email, PASSWORD));
    }
}
