package com.axchisan.gastos.servicio;

import com.axchisan.gastos.deteccion.AvisoBancario;
import com.axchisan.gastos.deteccion.ClaseMovimiento;
import com.axchisan.gastos.deteccion.LectorAvisosBancolombia;
import com.axchisan.gastos.deteccion.LectorExtractoBancolombia;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.MovimientoDetectado;
import com.axchisan.gastos.dominio.MovimientoDetectado.Estado;
import com.axchisan.gastos.dominio.MovimientoDetectado.Origen;
import com.axchisan.gastos.dominio.ReglaDeteccion;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MovimientoDetectadoRepository;
import com.axchisan.gastos.repositorio.ReglaDeteccionRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.axchisan.gastos.servicio.ServicioMovimientos.Movimiento;
import com.axchisan.gastos.servicio.ServicioMovimientos.TipoMovimiento;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * La bandeja de movimientos detectados: recibe avisos y extractos, los interpreta, quita lo
 * repetido y lo que ya estaba apuntado, aplica las reglas del usuario y deja el resto por revisar.
 *
 * <p>Nada de esto crea gastos ni ingresos: solo propone. Ver docs/REGISTRO-AUTOMATICO.md.
 */
@Service
public class ServicioDetectados {

    /** Días de diferencia que se toleran al cruzar: el extracto a veces fecha al día siguiente. */
    private static final int TOLERANCIA_DIAS = 1;

    private final MovimientoDetectadoRepository detectados;
    private final ReglaDeteccionRepository reglas;
    private final UsuarioRepository usuarios;
    private final MesPresupuestalRepository meses;
    private final ServicioMovimientos movimientos;

    public ServicioDetectados(MovimientoDetectadoRepository detectados,
                              ReglaDeteccionRepository reglas, UsuarioRepository usuarios,
                              MesPresupuestalRepository meses, ServicioMovimientos movimientos) {
        this.detectados = detectados;
        this.reglas = reglas;
        this.usuarios = usuarios;
        this.meses = meses;
        this.movimientos = movimientos;
    }

    public enum Resultado { NUEVO, REPETIDO, IGNORADO }

    public record AvisoRecibido(Resultado resultado, MovimientoDetectado detectado) {
    }

    /**
     * @param leidos      líneas de movimientos encontradas en el PDF
     * @param yaEstaban   las que ya se habían importado antes (el mismo PDF o uno que se solapa)
     * @param pendientes  las que quedaron por revisar
     */
    public record ResumenImportacion(String cuenta, LocalDate desde, LocalDate hasta, int leidos,
                                     int yaEstaban, int pendientes, int duplicados,
                                     int yaRegistrados, int descartados) {
    }

    // --- entrada ---

    @Transactional
    public AvisoRecibido recibirAviso(UUID usuarioId, Origen origen, String texto) {
        if (origen == Origen.PDF) {
            throw new IllegalArgumentException("Los extractos se importan aparte");
        }
        if (LectorAvisosBancolombia.noEsMovimiento(texto)) {
            return new AvisoRecibido(Resultado.IGNORADO, null);
        }
        String limpio = texto.replaceAll("\\s+", " ").trim();
        String huella = huella(origen.name(), limpio);
        if (detectados.existeHuella(usuarioId, huella)) {
            return new AvisoRecibido(Resultado.REPETIDO, null);
        }
        Usuario usuario = usuario(usuarioId);
        Optional<AvisoBancario> aviso = LectorAvisosBancolombia.leer(limpio);
        MovimientoDetectado d = aviso
                .map(a -> new MovimientoDetectado(usuario, origen, a, limpio, huella))
                .orElseGet(() -> MovimientoDetectado.noReconocido(usuario, origen,
                        LectorAvisosBancolombia.BANCO, limpio, huella));
        if (aviso.isPresent()) {
            procesar(usuarioId, d, new Contexto(usuarioId));
        }
        return new AvisoRecibido(Resultado.NUEVO, detectados.save(d));
    }

    @Transactional
    public ResumenImportacion importarExtracto(UUID usuarioId, byte[] pdf) {
        return importar(usuarioId, LectorExtractoBancolombia.leer(pdf));
    }

    @Transactional
    public ResumenImportacion importar(UUID usuarioId, LectorExtractoBancolombia.Extracto extracto) {
        if (extracto.lineas().isEmpty()) {
            throw new IllegalArgumentException(
                    "No se encontró ningún movimiento: ¿es el PDF «Movimientos» de Bancolombia?");
        }
        Usuario usuario = usuario(usuarioId);
        Contexto contexto = new Contexto(usuarioId);
        // Dos compras iguales el mismo día son dos líneas idénticas: el número de aparición
        // las distingue, y como el extracto es siempre el mismo, la huella se repite al
        // importar otra vez un PDF que se solapa.
        Map<String, Integer> apariciones = new HashMap<>();
        int yaEstaban = 0;
        int pendientes = 0;
        int duplicados = 0;
        int yaRegistrados = 0;
        int descartados = 0;
        LocalDate desde = null;
        LocalDate hasta = null;
        // Del más viejo al más reciente, para que los cruces sigan el orden en que ocurrieron.
        List<LectorExtractoBancolombia.Linea> lineas = extracto.lineas().reversed();
        for (LectorExtractoBancolombia.Linea linea : lineas) {
            AvisoBancario a = linea.aviso();
            desde = desde == null || a.fecha().isBefore(desde) ? a.fecha() : desde;
            hasta = hasta == null || a.fecha().isAfter(hasta) ? a.fecha() : hasta;
            String clave = a.fecha() + "|" + (a.entra() ? "+" : "-") + a.monto() + "|"
                    + linea.descripcion();
            int n = apariciones.merge(clave, 1, Integer::sum);
            String huella = huella(Origen.PDF.name(), extracto.cuenta() + "|" + clave + "|" + n);
            if (detectados.existeHuella(usuarioId, huella)) {
                yaEstaban++;
                continue;
            }
            String texto = a.fecha() + " " + linea.descripcion() + " "
                    + (a.entra() ? "" : "-") + "$ " + a.monto().toPlainString();
            MovimientoDetectado d = new MovimientoDetectado(usuario, Origen.PDF, a, texto, huella);
            procesar(usuarioId, d, contexto);
            detectados.save(d);
            // Se guarda al momento para que la siguiente línea pueda cruzarse con esta.
            detectados.flush();
            switch (d.getEstado()) {
                case PENDIENTE -> pendientes++;
                case DUPLICADO -> duplicados++;
                case YA_REGISTRADO -> yaRegistrados++;
                case DESCARTADO -> descartados++;
                default -> {
                }
            }
        }
        return new ResumenImportacion(extracto.cuenta(), desde, hasta, lineas.size(), yaEstaban,
                pendientes, duplicados, yaRegistrados, descartados);
    }

    // --- la bandeja ---

    @Transactional(readOnly = true)
    public List<MovimientoDetectado> listar(UUID usuarioId, Collection<Estado> estados) {
        return detectados.listar(usuarioId,
                estados == null || estados.isEmpty() ? List.of(Estado.PENDIENTE) : estados);
    }

    @Transactional
    public MovimientoDetectado descartar(UUID usuarioId, UUID id, String motivo) {
        MovimientoDetectado d = buscar(usuarioId, id);
        d.descartar(motivo == null || motivo.isBlank() ? "Descartado a mano" : motivo);
        return d;
    }

    @Transactional
    public MovimientoDetectado marcarYaRegistrado(UUID usuarioId, UUID id) {
        MovimientoDetectado d = buscar(usuarioId, id);
        d.marcarYaRegistrado(null, null, "Marcado a mano como ya registrado");
        return d;
    }

    @Transactional
    public MovimientoDetectado reabrir(UUID usuarioId, UUID id) {
        MovimientoDetectado d = buscar(usuarioId, id);
        try {
            d.reabrir();
        } catch (IllegalStateException e) {
            throw new IllegalArgumentException(e.getMessage());
        }
        return d;
    }

    // --- reglas ---

    @Transactional(readOnly = true)
    public List<ReglaDeteccion> reglas(UUID usuarioId) {
        return reglas.listarDelUsuario(usuarioId);
    }

    /** Crea la regla y la aplica a lo que esté pendiente. */
    @Transactional
    public ReglaDeteccion crearRegla(UUID usuarioId, ReglaDeteccion.Campo campo, String valor,
                                     ReglaDeteccion.Accion accion, ReglaDeteccion.Destino destino,
                                     String categoria, String nombre) {
        ReglaDeteccion regla = reglas.save(new ReglaDeteccion(usuario(usuarioId), campo, valor,
                accion, destino, categoria, nombre));
        for (MovimientoDetectado d : detectados.listar(usuarioId, List.of(Estado.PENDIENTE))) {
            if (regla.aplica(d.getReferencia(), d.getContraparte())) {
                d.aplicarRegla(regla);
            }
        }
        return regla;
    }

    @Transactional
    public void eliminarRegla(UUID usuarioId, UUID reglaId) {
        ReglaDeteccion regla = reglas.buscarDelUsuario(usuarioId, reglaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la regla", reglaId));
        reglas.delete(regla);
    }

    // --- el proceso ---

    /** Lo que se reutiliza mientras se procesa un lote: reglas y movimientos de cada mes. */
    private final class Contexto {
        private final UUID usuarioId;
        private final List<ReglaDeteccion> reglasDelUsuario;
        private final Map<YearMonth, List<Movimiento>> registrados = new HashMap<>();
        private final Set<UUID> reclamados;

        Contexto(UUID usuarioId) {
            this.usuarioId = usuarioId;
            this.reglasDelUsuario = reglas.listarDelUsuario(usuarioId);
            this.reclamados = new HashSet<>(detectados.registradosReclamados(usuarioId));
        }

        List<Movimiento> registradosEn(YearMonth periodo) {
            return registrados.computeIfAbsent(periodo, p -> meses
                    .buscarPorPeriodo(usuarioId, (short) p.getYear(), (short) p.getMonthValue())
                    .map(MesPresupuestal::getId)
                    .map(mesId -> movimientos.del(usuarioId, mesId).movimientos())
                    .orElse(List.of()));
        }
    }

    private void procesar(UUID usuarioId, MovimientoDetectado d, Contexto contexto) {
        Optional<MovimientoDetectado> original = mismoPorOtroCanal(usuarioId, d);
        if (original.isPresent()) {
            d.marcarDuplicado(original.get());
            return;
        }
        if (d.getClase() == ClaseMovimiento.INTERESES) {
            d.descartar("Intereses de la cuenta");
            return;
        }
        for (ReglaDeteccion regla : contexto.reglasDelUsuario) {
            if (regla.aplica(d.getReferencia(), d.getContraparte())) {
                d.aplicarRegla(regla);
                if (regla.getAccion() == ReglaDeteccion.Accion.DESCARTAR) {
                    return;
                }
                break;
            }
        }
        if (d.getClase() == ClaseMovimiento.RETIRO) {
            // Sacar del cajero mueve plata de la cuenta al efectivo: no es un gasto.
            d.descartar("Retiro de cajero: el efectivo sigue siendo tuyo");
            return;
        }
        Optional<Movimiento> registrado = yaRegistrado(d, contexto);
        if (registrado.isPresent()) {
            Movimiento m = registrado.get();
            if (m.tipo() != TipoMovimiento.SUELDO) {
                contexto.reclamados.add(m.id());
            }
            d.marcarYaRegistrado(m.tipo().name(), m.id(), "Ya está: " + m.titulo());
            return;
        }
        if (d.getSugerenciaDestino() == null) {
            d.sugerir(destinoPorDefecto(d.getClase()), null, null);
        }
    }

    /**
     * El mismo movimiento que ya llegó por otro canal: mismo banco, signo e importe exacto, a un
     * día como mucho. Cada original solo se empareja con un aviso de cada canal, para que dos
     * compras iguales el mismo día no se coman una a la otra.
     */
    private Optional<MovimientoDetectado> mismoPorOtroCanal(UUID usuarioId, MovimientoDetectado d) {
        List<MovimientoDetectado> parecidos = detectados.parecidos(usuarioId, d.getBanco(),
                d.getMonto(), d.getEntra(), d.getFecha().minusDays(TOLERANCIA_DIAS),
                d.getFecha().plusDays(TOLERANCIA_DIAS));
        Set<UUID> yaEmparejados = new HashSet<>();
        for (MovimientoDetectado p : parecidos) {
            if (p.getOrigen() == d.getOrigen() && p.getDuplicadoDe() != null) {
                yaEmparejados.add(p.getDuplicadoDe());
            }
        }
        return parecidos.stream()
                .filter(p -> !p.getId().equals(d.getId()))
                .filter(p -> p.getEstado() != Estado.DUPLICADO)
                .filter(p -> p.getOrigen() != d.getOrigen())
                .filter(p -> !yaEmparejados.contains(p.getId()))
                .min(Comparator.comparingLong(p -> distancia(p.getFecha(), d.getFecha())));
    }

    /** Lo ya apuntado en la app con el mismo importe y signo, a un día como mucho. */
    private Optional<Movimiento> yaRegistrado(MovimientoDetectado d, Contexto contexto) {
        Set<YearMonth> periodos = new HashSet<>();
        for (int i = -TOLERANCIA_DIAS; i <= TOLERANCIA_DIAS; i++) {
            periodos.add(ServicioInicio.periodoDe(d.getFecha().plusDays(i)));
        }
        return periodos.stream()
                .flatMap(p -> contexto.registradosEn(p).stream())
                .filter(m -> m.monto() != null && m.monto().compareTo(d.montoConSigno()) == 0)
                .filter(m -> m.fecha() != null
                        && distancia(m.fecha(), d.getFecha()) <= TOLERANCIA_DIAS)
                .filter(m -> m.tipo() == TipoMovimiento.SUELDO
                        || !contexto.reclamados.contains(m.id()))
                .min(Comparator.comparingLong(m -> distancia(m.fecha(), d.getFecha())));
    }

    private static ReglaDeteccion.Destino destinoPorDefecto(ClaseMovimiento clase) {
        return switch (clase) {
            case COMPRA, PAGO_QR -> ReglaDeteccion.Destino.COMPRA;
            case TRANSFERENCIA_RECIBIDA, NOMINA, INTERESES -> ReglaDeteccion.Destino.INGRESO;
            default -> ReglaDeteccion.Destino.GASTO;
        };
    }

    private static long distancia(LocalDate a, LocalDate b) {
        return Math.abs(ChronoUnit.DAYS.between(a, b));
    }

    private MovimientoDetectado buscar(UUID usuarioId, UUID id) {
        return detectados.buscarDelUsuario(usuarioId, id)
                .orElseThrow(() -> new RecursoNoEncontrado("el movimiento detectado", id));
    }

    private Usuario usuario(UUID usuarioId) {
        return usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));
    }

    static String huella(String origen, String contenido) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-256")
                    .digest((origen + "|" + contenido).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(h);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
