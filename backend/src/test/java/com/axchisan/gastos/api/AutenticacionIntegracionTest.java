package com.axchisan.gastos.api;

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
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("API de autenticación")
class AutenticacionIntegracionTest {

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

    @Nested
    @DisplayName("Registro")
    class Registro {

        @Test
        void creaLaCuentaYDevuelveLaSesionIniciada() throws Exception {
            mvc.perform(post("/api/auth/registro")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRegistro("duvan@axchisan.com")))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.accessToken").isNotEmpty())
                    .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                    .andExpect(jsonPath("$.expiraEn").value(900))
                    .andExpect(jsonPath("$.usuario.email").value("duvan@axchisan.com"))
                    .andExpect(jsonPath("$.usuario.moneda").value("COP"));
        }

        @Test
        void nuncaExponeElHashDeLaContrasena() throws Exception {
            String respuesta = mvc.perform(post("/api/auth/registro")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRegistro("duvan@axchisan.com")))
                    .andReturn().getResponse().getContentAsString();

            assertThat(respuesta).doesNotContain("password", "Hash", "$2a$");
        }

        @Test
        void normalizaElCorreoAMinusculas() throws Exception {
            mvc.perform(post("/api/auth/registro")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRegistro("Duvan@AxchiSan.COM")))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.usuario.email").value("duvan@axchisan.com"));
        }

        @Test
        void rechazaUnCorreoYaRegistrado() throws Exception {
            registrar("duvan@axchisan.com");

            mvc.perform(post("/api/auth/registro")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRegistro("duvan@axchisan.com")))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.error").value("email_ya_registrado"));
        }

        @Test
        void rechazaUnCorreoYaRegistradoAunqueCambieLaCapitalizacion() throws Exception {
            registrar("duvan@axchisan.com");

            mvc.perform(post("/api/auth/registro")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRegistro("DUVAN@AXCHISAN.COM")))
                    .andExpect(status().isConflict());
        }

        @Test
        void rechazaUnCorreoConFormatoInvalido() throws Exception {
            mvc.perform(post("/api/auth/registro")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"email":"no-es-un-correo","password":"clave12345",\
                                    "nombre":"Duvan"}"""))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.error").value("datos_invalidos"))
                    .andExpect(jsonPath("$.campos.email").isNotEmpty());
        }

        @Test
        void rechazaUnaContrasenaDemasiadoCorta() throws Exception {
            mvc.perform(post("/api/auth/registro")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"email":"duvan@axchisan.com","password":"corta",\
                                    "nombre":"Duvan"}"""))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.campos.password").isNotEmpty());
        }
    }

    @Nested
    @DisplayName("Inicio de sesión")
    class InicioDeSesion {

        @Test
        void devuelveTokensConCredencialesCorrectas() throws Exception {
            registrar("duvan@axchisan.com");

            mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("duvan@axchisan.com", PASSWORD)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.accessToken").isNotEmpty())
                    .andExpect(jsonPath("$.refreshToken").isNotEmpty());
        }

        @Test
        void aceptaElCorreoEnCualquierCapitalizacion() throws Exception {
            registrar("duvan@axchisan.com");

            mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("DUVAN@axchisan.COM", PASSWORD)))
                    .andExpect(status().isOk());
        }

        @Test
        void rechazaUnaContrasenaIncorrecta() throws Exception {
            registrar("duvan@axchisan.com");

            mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("duvan@axchisan.com", "claveEquivocada")))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.error").value("credenciales_invalidas"));
        }

        /**
         * Un correo inexistente y una contraseña incorrecta deben producir exactamente la misma
         * respuesta; de lo contrario se podría averiguar qué cuentas existen.
         */
        @Test
        void noDistingueEntreCorreoInexistenteYContrasenaIncorrecta() throws Exception {
            registrar("duvan@axchisan.com");

            String conCorreoDesconocido = mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("nadie@axchisan.com", PASSWORD)))
                    .andExpect(status().isUnauthorized())
                    .andReturn().getResponse().getContentAsString();

            String conClaveIncorrecta = mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("duvan@axchisan.com", "claveEquivocada")))
                    .andExpect(status().isUnauthorized())
                    .andReturn().getResponse().getContentAsString();

            assertThat(conCorreoDesconocido).isEqualTo(conClaveIncorrecta);
        }
    }

    @Nested
    @DisplayName("Acceso a recursos protegidos")
    class RecursosProtegidos {

        @Test
        void sinTokenDevuelveNoAutenticado() throws Exception {
            mvc.perform(get("/api/auth/yo"))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.error").value("no_autenticado"));
        }

        @Test
        void conTokenValidoDevuelveElUsuario() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");

            mvc.perform(get("/api/auth/yo")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.email").value("duvan@axchisan.com"))
                    .andExpect(jsonPath("$.nombre").value("Duvan"));
        }

        @Test
        void unTokenManipuladoEsRechazado() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");
            String token = sesion.get("accessToken").asText();
            // Se altera el último carácter de la firma.
            String manipulado = token.substring(0, token.length() - 1)
                    + (token.endsWith("A") ? "B" : "A");

            mvc.perform(get("/api/auth/yo").header("Authorization", "Bearer " + manipulado))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        void unTokenInventadoEsRechazado() throws Exception {
            mvc.perform(get("/api/auth/yo").header("Authorization", "Bearer esto.no.es"))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        void elEndpointDeSaludEsPublico() throws Exception {
            mvc.perform(get("/api/salud"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.estado").value("ok"));
        }
    }

    @Nested
    @DisplayName("Renovación de la sesión")
    class Renovacion {

        @Test
        void entregaTokensNuevosYDistintos() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");
            String refrescoOriginal = sesion.get("refreshToken").asText();

            String respuesta = mvc.perform(post("/api/auth/refresh")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco(refrescoOriginal)))
                    .andExpect(status().isOk())
                    .andReturn().getResponse().getContentAsString();

            // El token de refresco rota en cada uso: el anterior queda inservible.
            assertThat(json.readTree(respuesta).get("refreshToken").asText())
                    .isNotEqualTo(refrescoOriginal);
        }

        /**
         * Reutilizar un token ya consumido delata que fue robado, así que se revoca la familia
         * completa y también el token nuevo deja de servir.
         */
        @Test
        void reutilizarUnTokenRevocaLaSesionEntera() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");
            String primero = sesion.get("refreshToken").asText();

            String respuesta = mvc.perform(post("/api/auth/refresh")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco(primero)))
                    .andExpect(status().isOk())
                    .andReturn().getResponse().getContentAsString();
            String segundo = json.readTree(respuesta).get("refreshToken").asText();

            // Se presenta de nuevo el primero, ya consumido.
            mvc.perform(post("/api/auth/refresh")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco(primero)))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.error").value("token_invalido"));

            // El segundo, que era legítimo, también queda revocado.
            mvc.perform(post("/api/auth/refresh")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco(segundo)))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        void unTokenInexistenteEsRechazado() throws Exception {
            mvc.perform(post("/api/auth/refresh")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco("token-que-no-existe")))
                    .andExpect(status().isUnauthorized());
        }
    }

    @Nested
    @DisplayName("Cierre de sesión")
    class CierreDeSesion {

        @Test
        void invalidaElTokenDeRefresco() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");
            String refresco = sesion.get("refreshToken").asText();

            mvc.perform(post("/api/auth/logout")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco(refresco)))
                    .andExpect(status().isNoContent());

            mvc.perform(post("/api/auth/refresh")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco(refresco)))
                    .andExpect(status().isUnauthorized());
        }
    }

    @Nested
    @DisplayName("Cambio de credenciales")
    class CambioDeCredenciales {

        private static final String NUEVA = "otraClaveSegura456";

        @Test
        void cambiaLaContrasenaYDevuelveUnaSesionNueva() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");

            mvc.perform(patch("/api/auth/password")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"passwordActual":"%s","passwordNueva":"%s"}"""
                                    .formatted(PASSWORD, NUEVA)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.accessToken").isNotEmpty());

            // La contraseña anterior deja de servir y la nueva funciona.
            mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("duvan@axchisan.com", PASSWORD)))
                    .andExpect(status().isUnauthorized());

            mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("duvan@axchisan.com", NUEVA)))
                    .andExpect(status().isOk());
        }

        /**
         * Cambiar la contraseña debe expulsar al resto de dispositivos: si se cambió por sospecha
         * de robo, dejar las demás sesiones vivas no serviría de nada.
         */
        @Test
        void cambiarLaContrasenaRevocaLasSesionesAnteriores() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");
            String refrescoAnterior = sesion.get("refreshToken").asText();

            mvc.perform(patch("/api/auth/password")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"passwordActual":"%s","passwordNueva":"%s"}"""
                                    .formatted(PASSWORD, NUEVA)))
                    .andExpect(status().isOk());

            mvc.perform(post("/api/auth/refresh")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoRefresco(refrescoAnterior)))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        void exigeLaContrasenaActualParaCambiarla() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");

            mvc.perform(patch("/api/auth/password")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"passwordActual":"laQueNoEs","passwordNueva":"%s"}"""
                                    .formatted(NUEVA)))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.error").value("credenciales_invalidas"));
        }

        @Test
        void rechazaRepetirLaMismaContrasena() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");

            mvc.perform(patch("/api/auth/password")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"passwordActual":"%s","passwordNueva":"%s"}"""
                                    .formatted(PASSWORD, PASSWORD)))
                    .andExpect(status().isBadRequest());
        }

        @Test
        void cambiaElCorreoDeAcceso() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");

            mvc.perform(patch("/api/auth/email")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"password":"%s","emailNuevo":"nuevo@axchisan.com"}"""
                                    .formatted(PASSWORD)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.usuario.email").value("nuevo@axchisan.com"));

            mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("nuevo@axchisan.com", PASSWORD)))
                    .andExpect(status().isOk());

            mvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpoLogin("duvan@axchisan.com", PASSWORD)))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        void exigeLaContrasenaParaCambiarElCorreo() throws Exception {
            JsonNode sesion = registrar("duvan@axchisan.com");

            mvc.perform(patch("/api/auth/email")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"password":"laQueNoEs","emailNuevo":"nuevo@axchisan.com"}"""))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        void cambiaElNombreSinPedirContrasena() throws Exception {
            // El nombre no da acceso a nada, así que no forma parte de las credenciales.
            JsonNode sesion = registrar("duvan@axchisan.com");

            mvc.perform(patch("/api/auth/nombre")
                            .header("Authorization", "Bearer " + sesion.get("accessToken").asText())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"nombre":"Duvan Andrés"}"""))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.nombre").value("Duvan Andrés"));
        }

        @Test
        void sinSesionNoSePuedenCambiarLasCredenciales() throws Exception {
            mvc.perform(patch("/api/auth/password")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"passwordActual":"x","passwordNueva":"%s"}""".formatted(NUEVA)))
                    .andExpect(status().isUnauthorized());
        }
    }

    // --- utilidades ---

    private JsonNode registrar(String email) throws Exception {
        MvcResult resultado = mvc.perform(post("/api/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpoRegistro(email)))
                .andExpect(status().isCreated())
                .andReturn();
        return json.readTree(resultado.getResponse().getContentAsString());
    }

    private String cuerpoRegistro(String email) {
        return """
                {"email":"%s","password":"%s","nombre":"Duvan"}""".formatted(email, PASSWORD);
    }

    private String cuerpoLogin(String email, String password) {
        return """
                {"email":"%s","password":"%s"}""".formatted(email, password);
    }

    private String cuerpoRefresco(String token) {
        return """
                {"refreshToken":"%s"}""".formatted(token);
    }
}
