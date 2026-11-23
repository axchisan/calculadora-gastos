package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.ClaveIngesta;
import com.axchisan.gastos.dominio.MovimientoDetectado;
import com.axchisan.gastos.repositorio.ClaveIngestaRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Claves de ingesta y recepción de avisos en lote, venga del teléfono, de Gmail o de la app.
 */
@Service
public class ServicioIngesta {

    /** Lo máximo que se acepta en una petición: el historial de SMS se manda por partes. */
    public static final int MAXIMO_POR_LOTE = 200;

    private static final String PREFIJO = "gk_";
    private static final SecureRandom AZAR = new SecureRandom();

    private final ClaveIngestaRepository claves;
    private final UsuarioRepository usuarios;
    private final ServicioDetectados detectados;

    public ServicioIngesta(ClaveIngestaRepository claves, UsuarioRepository usuarios,
                           ServicioDetectados detectados) {
        this.claves = claves;
        this.usuarios = usuarios;
        this.detectados = detectados;
    }

    /** Una clave recién creada: es la única vez que se puede ver. */
    public record ClaveNueva(ClaveIngesta clave, String secreto) {
    }

    public record Aviso(MovimientoDetectado.Origen origen, String texto) {
    }

    public record ResultadoLote(int nuevos, int repetidos, int ignorados, int noReconocidos) {
    }

    @Transactional
    public ClaveNueva crear(UUID usuarioId, String nombre) {
        var usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));
        byte[] bytes = new byte[32];
        AZAR.nextBytes(bytes);
        String secreto = PREFIJO + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        String limpio = nombre == null || nombre.isBlank() ? "Dispositivo" : nombre.trim();
        ClaveIngesta clave = claves.save(new ClaveIngesta(usuario, limpio, huella(secreto)));
        return new ClaveNueva(clave, secreto);
    }

    @Transactional(readOnly = true)
    public List<ClaveIngesta> listar(UUID usuarioId) {
        return claves.activasDelUsuario(usuarioId);
    }

    @Transactional
    public void revocar(UUID usuarioId, UUID id) {
        claves.buscarDelUsuario(usuarioId, id)
                .orElseThrow(() -> new RecursoNoEncontrado("la clave", id))
                .revocar();
    }

    /** El usuario dueño de la clave, si existe y no está revocada. */
    @Transactional
    public Optional<UUID> autenticar(String secreto) {
        if (secreto == null || !secreto.startsWith(PREFIJO) || secreto.length() > 100) {
            return Optional.empty();
        }
        return claves.buscarActivaPorHuella(huella(secreto.trim())).map(c -> {
            c.registrarUso();
            return c.getUsuario().getId();
        });
    }

    /** Procesa varios avisos; uno que falle no impide los demás. */
    public ResultadoLote recibir(UUID usuarioId, List<Aviso> avisos) {
        if (avisos == null || avisos.isEmpty()) {
            throw new IllegalArgumentException("No llegó ningún aviso");
        }
        if (avisos.size() > MAXIMO_POR_LOTE) {
            throw new IllegalArgumentException(
                    "Como mucho " + MAXIMO_POR_LOTE + " avisos por petición");
        }
        int nuevos = 0;
        int repetidos = 0;
        int ignorados = 0;
        int noReconocidos = 0;
        for (Aviso a : avisos) {
            if (a == null || a.origen() == null || a.texto() == null || a.texto().isBlank()) {
                ignorados++;
                continue;
            }
            ServicioDetectados.AvisoRecibido r;
            try {
                r = detectados.recibirAviso(usuarioId, a.origen(), a.texto());
            } catch (IllegalArgumentException
                     | org.springframework.dao.DataIntegrityViolationException e) {
                // El mismo aviso llegando dos veces a la vez (SMS y reintento) choca con la
                // huella única: ya está guardado.
                repetidos++;
                continue;
            }
            switch (r.resultado()) {
                case NUEVO -> {
                    if (r.detectado().getEstado() == MovimientoDetectado.Estado.NO_RECONOCIDO) {
                        noReconocidos++;
                    } else {
                        nuevos++;
                    }
                }
                case REPETIDO -> repetidos++;
                case IGNORADO -> ignorados++;
            }
        }
        return new ResultadoLote(nuevos, repetidos, ignorados, noReconocidos);
    }

    static String huella(String secreto) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(secreto.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
