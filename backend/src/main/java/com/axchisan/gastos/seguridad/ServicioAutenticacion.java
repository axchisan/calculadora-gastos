package com.axchisan.gastos.seguridad;

import com.axchisan.gastos.dominio.RefreshToken;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.RefreshTokenRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Registro, inicio de sesión, renovación y cierre de sesión. */
@Service
public class ServicioAutenticacion {

    private static final Logger log = LoggerFactory.getLogger(ServicioAutenticacion.class);

    private final UsuarioRepository usuarios;
    private final RefreshTokenRepository refrescos;
    private final ServicioTokens tokens;
    private final PasswordEncoder codificador;
    private final LimitadorIntentos limitador;

    public ServicioAutenticacion(UsuarioRepository usuarios, RefreshTokenRepository refrescos,
                                 ServicioTokens tokens, PasswordEncoder codificador,
                                 LimitadorIntentos limitador) {
        this.usuarios = usuarios;
        this.refrescos = refrescos;
        this.tokens = tokens;
        this.codificador = codificador;
        this.limitador = limitador;
    }

    /** Crea una cuenta y devuelve la sesión ya iniciada. */
    @Transactional
    public Sesion registrar(String email, String password, String nombre) {
        String normalizado = Usuario.normalizarEmail(email);
        if (usuarios.existeConEmail(normalizado)) {
            throw new ExcepcionesAutenticacion.EmailYaRegistrado();
        }
        Usuario usuario = usuarios.save(
                new Usuario(normalizado, codificador.encode(password), nombre));
        log.info("Cuenta creada para el usuario {}", usuario.getId());
        return abrirSesion(usuario, UUID.randomUUID());
    }

    /** Valida las credenciales y abre una sesión nueva. */
    @Transactional
    public Sesion iniciarSesion(String email, String password) {
        String normalizado = Usuario.normalizarEmail(email);
        limitador.verificar(normalizado);

        Usuario usuario = usuarios.buscarPorEmail(normalizado).orElse(null);

        // Se verifica la contraseña incluso cuando el correo no existe, contra un hash señuelo:
        // BCrypt tarda cientos de milisegundos, así que responder de inmediato ante un correo
        // desconocido revelaría cuáles están registrados.
        String hash = usuario != null ? usuario.getPasswordHash() : HASH_SENUELO;
        boolean passwordCorrecta = codificador.matches(password, hash);

        if (usuario == null || !passwordCorrecta || !usuario.isActivo()) {
            limitador.registrarFallo(normalizado);
            throw new ExcepcionesAutenticacion.CredencialesInvalidas();
        }

        limitador.registrarExito(normalizado);
        return abrirSesion(usuario, UUID.randomUUID());
    }

    /**
     * Renueva la sesión rotando el token de refresco.
     *
     * <p>Si el token presentado ya se había usado, se asume que fue robado y se revoca la familia
     * completa: tanto el atacante como el usuario legítimo pierden la sesión, y este último tendrá
     * que volver a entrar.
     *
     * <p>El {@code noRollbackFor} es imprescindible: sin él, la excepción que se lanza tras
     * detectar la reutilización revertiría la propia revocación que acaba de hacerse, dejando los
     * tokens robados operativos.
     */
    @Transactional(noRollbackFor = ExcepcionesAutenticacion.TokenInvalido.class)
    public Sesion refrescar(String refreshToken) {
        RefreshToken almacenado = refrescos.findByTokenHash(tokens.hashear(refreshToken))
                .orElseThrow(() -> new ExcepcionesAutenticacion.TokenInvalido(
                        "El token de refresco no es válido"));

        if (almacenado.fueUsado()) {
            int revocados = refrescos.revocarFamilia(almacenado.getFamilia(), OffsetDateTime.now());
            log.warn("Token de refresco reutilizado del usuario {}: se revocaron {} tokens",
                    almacenado.getUsuario().getId(), revocados);
            throw new ExcepcionesAutenticacion.TokenInvalido(
                    "El token de refresco ya se había usado; la sesión fue revocada");
        }

        if (!almacenado.estaVigente()) {
            throw new ExcepcionesAutenticacion.TokenInvalido(
                    "El token de refresco caducó o fue revocado");
        }

        almacenado.marcarUsado();
        return abrirSesion(almacenado.getUsuario(), almacenado.getFamilia());
    }

    /** Cierra la sesión asociada al token de refresco. */
    @Transactional
    public void cerrarSesion(String refreshToken) {
        refrescos.findByTokenHash(tokens.hashear(refreshToken))
                .ifPresent(t -> refrescos.revocarFamilia(t.getFamilia(), OffsetDateTime.now()));
    }

    /** Cierra todas las sesiones abiertas del usuario. */
    @Transactional
    public void cerrarTodasLasSesiones(UUID usuarioId) {
        refrescos.revocarTodosDelUsuario(usuarioId, OffsetDateTime.now());
    }

    private Sesion abrirSesion(Usuario usuario, UUID familia) {
        String refresco = tokens.generarRefreshToken();
        refrescos.save(new RefreshToken(
                usuario,
                tokens.hashear(refresco),
                familia,
                OffsetDateTime.now().plus(tokens.propiedades().duracionRefresco())));

        return new Sesion(
                tokens.emitirAccessToken(usuario),
                refresco,
                tokens.propiedades().duracionAcceso().toSeconds(),
                usuario);
    }

    /**
     * Hash de una contraseña arbitraria, usado como señuelo cuando el correo no existe para que
     * comprobarlo cueste lo mismo que con un usuario real.
     */
    private static final String HASH_SENUELO =
            "$2a$12$C6UzMDM.H6dfI/f/IKcEe.7Ll3fJ2mMHfBv7bHRQwqzGPYs9Nl1xy";
}
