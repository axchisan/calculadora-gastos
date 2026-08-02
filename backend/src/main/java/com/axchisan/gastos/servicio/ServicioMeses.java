package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.PlantillaGasto;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.PlantillaGastoRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

/** Alta y gestión de los meses del presupuesto. */
@Service
public class ServicioMeses {

    private static final Logger log = LoggerFactory.getLogger(ServicioMeses.class);

    private final MesPresupuestalRepository meses;
    private final PlantillaGastoRepository plantillas;
    private final UsuarioRepository usuarios;
    private final ServicioTransporteMes transporte;

    public ServicioMeses(MesPresupuestalRepository meses, PlantillaGastoRepository plantillas,
                         UsuarioRepository usuarios, ServicioTransporteMes transporte) {
        this.meses = meses;
        this.plantillas = plantillas;
        this.usuarios = usuarios;
        this.transporte = transporte;
    }

    /**
     * Crea un mes con los gastos fijos ya copiados y el transporte precalculado.
     *
     * <p>El sueldo y la tarifa del pasaje se heredan del último mes registrado, que suele ser la
     * mejor estimación disponible. Ambos son editables después.
     *
     * @throws MesYaExiste si el usuario ya tiene ese periodo
     */
    @Transactional
    public MesPresupuestal crear(UUID usuarioId, YearMonth periodo, BigDecimal ingresoBase,
                                 BigDecimal valorPasaje) {
        short anio = (short) periodo.getYear();
        short mes = (short) periodo.getMonthValue();

        if (meses.existePeriodo(usuarioId, anio, mes)) {
            throw new MesYaExiste(periodo);
        }

        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));

        MesPresupuestal anterior = ultimoMes(usuarioId).orElse(null);
        BigDecimal ingreso = ingresoBase != null ? ingresoBase
                : anterior != null ? anterior.getIngresoBase() : BigDecimal.ZERO;

        MesPresupuestal nuevo = meses.save(new MesPresupuestal(usuario, periodo, ingreso));

        // Los gastos fijos se copian desde la plantilla; a partir de aquí son independientes de
        // ella, de modo que editar la plantilla no reescribe el histórico.
        List<PlantillaGasto> activas = plantillas.listarActivas(usuarioId);
        for (PlantillaGasto plantilla : activas) {
            Gasto gasto = plantilla.generarGasto();
            nuevo.agregarGasto(gasto);
        }

        transporte.inicializar(nuevo, valorPasaje, anterior);

        meses.save(nuevo);
        log.info("Mes {} creado para el usuario {} con {} gastos fijos",
                periodo, usuarioId, activas.size());
        return nuevo;
    }

    /** Crea el mes solo si no existía; si ya estaba, devuelve el existente. */
    @Transactional
    public MesPresupuestal obtenerOCrear(UUID usuarioId, YearMonth periodo) {
        return meses.buscarPorPeriodo(usuarioId, (short) periodo.getYear(),
                        (short) periodo.getMonthValue())
                .orElseGet(() -> crear(usuarioId, periodo, null, null));
    }

    @Transactional(readOnly = true)
    public MesPresupuestal buscar(UUID usuarioId, UUID mesId) {
        return meses.buscarDelUsuario(usuarioId, mesId)
                .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));
    }

    @Transactional(readOnly = true)
    public MesPresupuestal buscarPorPeriodo(UUID usuarioId, YearMonth periodo) {
        return meses.buscarPorPeriodo(usuarioId, (short) periodo.getYear(),
                        (short) periodo.getMonthValue())
                .orElseThrow(() -> new RecursoNoEncontrado(
                        "el mes " + periodo + " no está registrado"));
    }

    @Transactional(readOnly = true)
    public List<MesPresupuestal> listar(UUID usuarioId) {
        return meses.listarDelUsuario(usuarioId);
    }

    @Transactional(readOnly = true)
    public java.util.Optional<MesPresupuestal> ultimoMes(UUID usuarioId) {
        return meses.listarDelUsuario(usuarioId).stream().findFirst();
    }

    @Transactional
    public MesPresupuestal actualizarIngreso(UUID usuarioId, UUID mesId, BigDecimal ingresoBase) {
        MesPresupuestal mes = buscar(usuarioId, mesId);
        verificarAbierto(mes);
        mes.setIngresoBase(ingresoBase);
        return meses.save(mes);
    }

    @Transactional
    public MesPresupuestal actualizarNotas(UUID usuarioId, UUID mesId, String notas) {
        MesPresupuestal mes = buscar(usuarioId, mesId);
        mes.setNotas(notas);
        return meses.save(mes);
    }

    /** Cierra el mes: queda como registro histórico y deja de admitir cambios. */
    @Transactional
    public MesPresupuestal cerrar(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = buscar(usuarioId, mesId);
        mes.setCerrado(true);
        return meses.save(mes);
    }

    @Transactional
    public MesPresupuestal reabrir(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = buscar(usuarioId, mesId);
        mes.setCerrado(false);
        return meses.save(mes);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID mesId) {
        meses.delete(buscar(usuarioId, mesId));
    }

    /** Impide modificar un mes ya cerrado. */
    static void verificarAbierto(MesPresupuestal mes) {
        if (mes.isCerrado()) {
            throw new MesCerrado(mes.periodo());
        }
    }

    /** El periodo ya está registrado para ese usuario. */
    public static class MesYaExiste extends RuntimeException {
        public MesYaExiste(YearMonth periodo) {
            super("El mes " + periodo + " ya está registrado");
        }
    }

    /** No se puede modificar un mes cerrado sin reabrirlo antes. */
    public static class MesCerrado extends RuntimeException {
        public MesCerrado(YearMonth periodo) {
            super("El mes " + periodo + " está cerrado; reábrelo para poder modificarlo");
        }
    }
}
