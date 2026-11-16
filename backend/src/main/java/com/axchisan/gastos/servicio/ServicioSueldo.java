package com.axchisan.gastos.servicio;

import com.axchisan.gastos.calendario.CalculadoraFestivos;
import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.MedioCobro;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.PagoRecibido;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
import com.axchisan.gastos.repositorio.PagoRecibidoRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.axchisan.gastos.sueldo.CalculadoraSueldo;
import com.axchisan.gastos.sueldo.ClienteTrm;
import com.axchisan.gastos.sueldo.PagoProyectado;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/** Ingresos en otra moneda: sus condiciones, sus pagos esperados y su paso al presupuesto. */
@Service
public class ServicioSueldo {

    /** La TRM es colombiana y cambia a medianoche de Colombia, no de donde corra el servidor. */
    private static final ZoneId COLOMBIA = ZoneId.of("America/Bogota");

    private final FuenteIngresoRepository fuentes;
    private final PagoRecibidoRepository pagos;
    private final UsuarioRepository usuarios;
    private final CalculadoraFestivos festivos;
    private final ServicioMeses meses;
    private final ClienteTrm clienteTrm;

    public ServicioSueldo(FuenteIngresoRepository fuentes, PagoRecibidoRepository pagos,
                          UsuarioRepository usuarios, CalculadoraFestivos festivos,
                          ServicioMeses meses, ClienteTrm clienteTrm) {
        this.fuentes = fuentes;
        this.pagos = pagos;
        this.usuarios = usuarios;
        this.festivos = festivos;
        this.meses = meses;
        this.clienteTrm = clienteTrm;
    }

    public static LocalDate hoy() {
        return LocalDate.now(COLOMBIA);
    }

    /** La TRM oficial vigente hoy, si se pudo consultar. */
    public Optional<ClienteTrm.Trm> trmDeHoy() {
        return clienteTrm.vigenteEn(hoy());
    }

    /**
     * Pone al día la TRM de las fuentes que la toman automáticamente.
     *
     * <p>Se llama al listar: así la cifra está fresca cada vez que se mira el sueldo, sin
     * depender de una tarea programada. Si la consulta falla, se conserva la última.
     */
    @Transactional
    public void refrescarTrm(UUID usuarioId) {
        LocalDate hoy = hoy();
        List<FuenteIngreso> pendientes = fuentes.listarDelUsuario(usuarioId).stream()
                .filter(f -> f.isActivo() && f.isTrmAutomatica() && f.getTrmFecha().isBefore(hoy))
                .toList();
        if (pendientes.isEmpty()) {
            return;
        }
        clienteTrm.vigenteEn(hoy).ifPresent(trm -> pendientes.forEach(f -> {
            f.actualizarTrm(trm.valor(), hoy);
            fuentes.save(f);
        }));
    }

    @Transactional(readOnly = true)
    public List<FuenteIngreso> listar(UUID usuarioId) {
        return fuentes.listarDelUsuario(usuarioId);
    }

    @Transactional(readOnly = true)
    public FuenteIngreso buscar(UUID usuarioId, UUID fuenteId) {
        return fuentes.buscarDelUsuario(usuarioId, fuenteId)
                .orElseThrow(() -> new RecursoNoEncontrado("el ingreso", fuenteId));
    }

    /** Datos editables de una fuente; los nulos se dejan como estaban. */
    public record Cambios(String nombre, BigDecimal montoMensual, LocalDate fechaInicio,
                          LocalDate fechaFin, Boolean quitarFechaFin, MedioCobro medio,
                          String cuentaDestino, Integer diasHabilesPago, Integer diasTolerancia,
                          BigDecimal trm, LocalDate trmFecha, BigDecimal comisionPorcentaje,
                          BigDecimal comisionFija, BigDecimal descuentoCambioPorcentaje,
                          BigDecimal costoRetiro, Boolean activo, String notas,
                          Boolean trmAutomatica) {
    }

    @Transactional
    public FuenteIngreso crear(UUID usuarioId, Cambios datos) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));
        if (datos.nombre() == null || datos.montoMensual() == null
                || datos.fechaInicio() == null) {
            throw new IllegalArgumentException(
                    "Faltan datos: nombre, monto mensual y fecha de inicio son obligatorios");
        }
        // Sin TRM tecleada se toma la oficial; si tampoco se puede consultar, no hay con qué
        // calcular y es mejor decirlo que inventar una cifra.
        BigDecimal trm = datos.trm();
        boolean automatica = datos.trm() == null || Boolean.TRUE.equals(datos.trmAutomatica());
        if (trm == null) {
            trm = trmDeHoy().map(ClienteTrm.Trm::valor).orElseThrow(() ->
                    new IllegalArgumentException(
                            "No se pudo consultar la TRM de hoy: escríbela a mano"));
        }
        FuenteIngreso fuente = new FuenteIngreso(usuario, datos.nombre(), datos.montoMensual(),
                datos.fechaInicio(), trm,
                datos.trmFecha() != null ? datos.trmFecha() : hoy());
        fuente.setTrmAutomatica(automatica);
        // Al crearla se parte de los costos típicos del medio; después se pueden afinar.
        fuente.usarCostosTipicosDe(datos.medio() != null ? datos.medio() : MedioCobro.TRANSFERENCIA);
        aplicar(fuente, new Cambios(null, null, null, datos.fechaFin(), null, null,
                datos.cuentaDestino(), datos.diasHabilesPago(), datos.diasTolerancia(), null, null,
                datos.comisionPorcentaje(), datos.comisionFija(),
                datos.descuentoCambioPorcentaje(), datos.costoRetiro(), datos.activo(),
                datos.notas(), null));
        return fuentes.save(fuente);
    }

    @Transactional
    public FuenteIngreso actualizar(UUID usuarioId, UUID fuenteId, Cambios cambios) {
        FuenteIngreso fuente = buscar(usuarioId, fuenteId);
        // Cambiar de medio arrastra sus costos típicos; si en la misma petición llegan costos
        // concretos, esos mandan porque se aplican después.
        if (cambios.medio() != null && cambios.medio() != fuente.getMedio()) {
            fuente.usarCostosTipicosDe(cambios.medio());
        }
        aplicar(fuente, cambios);

        // Volver a la automática trae en el acto la TRM de hoy, en vez de esperar a mañana.
        if (Boolean.TRUE.equals(cambios.trmAutomatica())) {
            trmDeHoy().ifPresent(t -> fuente.actualizarTrm(t.valor(), hoy()));
        }
        return fuentes.save(fuente);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID fuenteId) {
        fuentes.delete(buscar(usuarioId, fuenteId));
    }

    /** Los próximos pagos a partir del mes indicado (o del actual). */
    @Transactional(readOnly = true)
    public List<PagoProyectado> proyeccion(UUID usuarioId, UUID fuenteId, YearMonth desde,
                                           int cantidad) {
        FuenteIngreso fuente = buscar(usuarioId, fuenteId);
        return CalculadoraSueldo.proyectar(fuente.condiciones(),
                desde != null ? desde : YearMonth.from(hoy()),
                Math.max(1, Math.min(cantidad, 24)), festivos::esNoLaborable);
    }

    @Transactional(readOnly = true)
    public List<PagoRecibido> pagosRecibidos(UUID usuarioId, UUID fuenteId) {
        buscar(usuarioId, fuenteId);
        return pagos.deLaFuente(fuenteId);
    }

    /**
     * Anota lo que de verdad llegó de un pago y lo pone como sueldo base del mes en que entró.
     *
     * <p>El monto en la moneda original sale de la proyección de ese mes, que es exacto: lo
     * único incierto de un pago es la tasa, y esa se conoce al ver los pesos que llegaron.
     */
    @Transactional
    public PagoRecibido registrarPago(UUID usuarioId, UUID fuenteId, YearMonth mesDePago,
                                      BigDecimal montoPesos, LocalDate fecha,
                                      BigDecimal montoOriginal) {
        FuenteIngreso fuente = buscar(usuarioId, fuenteId);
        LocalDate dia = fecha != null ? fecha : hoy();

        BigDecimal original = montoOriginal;
        if (original == null) {
            original = CalculadoraSueldo.proyectar(fuente.condiciones(), mesDePago, 1,
                            festivos::esNoLaborable).stream()
                    .filter(p -> p.mesDePago().equals(mesDePago))
                    .findFirst()
                    .map(PagoProyectado::montoOriginal)
                    .orElseThrow(() -> new IllegalArgumentException(
                            "No hay ningún pago previsto en " + mesDePago));
        }

        PagoRecibido pago = pagos.delMes(fuenteId, mesDePago.toString()).orElse(null);
        if (pago == null) {
            pago = new PagoRecibido(fuente, mesDePago, original, montoPesos, dia);
        } else {
            pago.corregir(original, montoPesos, dia);
        }
        pago = pagos.save(pago);

        MesPresupuestal mes = meses.obtenerOCrear(usuarioId,
                CalculadoraSueldo.mesPresupuestal(dia));
        if (!mes.isCerrado()) {
            meses.actualizarIngreso(usuarioId, mes.getId(), montoPesos);
        }
        return pago;
    }

    @Transactional
    public void eliminarPago(UUID usuarioId, UUID fuenteId, YearMonth mesDePago) {
        buscar(usuarioId, fuenteId);
        pagos.delMes(fuenteId, mesDePago.toString()).ifPresent(pagos::delete);
    }

    /**
     * Lleva los pagos proyectados al sueldo base de cada mes presupuestal.
     *
     * <p>Los meses que no existen se crean. Los cerrados no se tocan, y tampoco los meses cuyo
     * pago ya llegó: ahí manda lo que de verdad entró.
     *
     * @return los meses actualizados con su nuevo sueldo base
     */
    @Transactional
    public Map<YearMonth, BigDecimal> llevarAlPresupuesto(UUID usuarioId, UUID fuenteId,
                                                          YearMonth desde, int cantidad) {
        Map<YearMonth, BigDecimal> porMes = new LinkedHashMap<>();
        for (PagoProyectado pago : proyeccion(usuarioId, fuenteId, desde, cantidad)) {
            if (pagos.delMes(fuenteId, pago.mesDePago().toString()).isPresent()) {
                continue;
            }
            porMes.merge(pago.mesPresupuestal(), pago.montoPesos(), BigDecimal::add);
        }

        Map<YearMonth, BigDecimal> aplicados = new LinkedHashMap<>();
        porMes.forEach((periodo, monto) -> {
            MesPresupuestal mes = meses.obtenerOCrear(usuarioId, periodo);
            if (mes.isCerrado()) {
                return;
            }
            meses.actualizarIngreso(usuarioId, mes.getId(), monto);
            aplicados.put(periodo, monto);
        });
        return aplicados;
    }

    private static void aplicar(FuenteIngreso f, Cambios c) {
        if (c.nombre() != null) {
            f.setNombre(c.nombre());
        }
        if (c.montoMensual() != null) {
            if (c.montoMensual().signum() <= 0) {
                throw new IllegalArgumentException("El monto mensual debe ser mayor que cero");
            }
            f.setMontoMensual(c.montoMensual());
        }
        if (c.fechaInicio() != null) {
            f.setFechaInicio(c.fechaInicio());
        }
        if (Boolean.TRUE.equals(c.quitarFechaFin())) {
            f.setFechaFin(null);
        } else if (c.fechaFin() != null) {
            f.setFechaFin(c.fechaFin());
        }
        if (f.getFechaFin() != null && f.getFechaFin().isBefore(f.getFechaInicio())) {
            throw new IllegalArgumentException("La fecha de fin no puede ser anterior al inicio");
        }
        if (c.cuentaDestino() != null) {
            f.setCuentaDestino(c.cuentaDestino().isBlank() ? null : c.cuentaDestino());
        }
        if (c.diasHabilesPago() != null) {
            if (c.diasHabilesPago() < 1 || c.diasHabilesPago() > 20) {
                throw new IllegalArgumentException("Los días hábiles de pago van de 1 a 20");
            }
            f.setDiasHabilesPago(c.diasHabilesPago().shortValue());
        }
        if (c.diasTolerancia() != null) {
            if (c.diasTolerancia() < 0 || c.diasTolerancia() > 10) {
                throw new IllegalArgumentException("La tolerancia va de 0 a 10 días hábiles");
            }
            f.setDiasTolerancia(c.diasTolerancia().shortValue());
        }
        if (c.trm() != null) {
            f.actualizarTrm(c.trm(), c.trmFecha());
            // Escribir una TRM a mano es fijarla: si no, mañana la automática la pisaría.
            if (c.trmAutomatica() == null) {
                f.setTrmAutomatica(false);
            }
        }
        if (c.trmAutomatica() != null) {
            f.setTrmAutomatica(c.trmAutomatica());
        }
        if (c.comisionPorcentaje() != null) {
            f.setComisionPorcentaje(noNegativo(c.comisionPorcentaje()));
        }
        if (c.comisionFija() != null) {
            f.setComisionFija(noNegativo(c.comisionFija()));
        }
        if (c.descuentoCambioPorcentaje() != null) {
            f.setDescuentoCambioPorcentaje(noNegativo(c.descuentoCambioPorcentaje()));
        }
        if (c.costoRetiro() != null) {
            f.setCostoRetiro(noNegativo(c.costoRetiro()));
        }
        if (c.activo() != null) {
            f.setActivo(c.activo());
        }
        if (c.notas() != null) {
            f.setNotas(c.notas().isBlank() ? null : c.notas());
        }
    }

    private static BigDecimal noNegativo(BigDecimal valor) {
        if (valor.signum() < 0) {
            throw new IllegalArgumentException("Los costos no pueden ser negativos");
        }
        return valor;
    }
}
