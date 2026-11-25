package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CuotaCredito;
import com.axchisan.gastos.dominio.Credito;
import com.axchisan.gastos.dominio.Deuda;
import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.MetaAhorro;
import com.axchisan.gastos.dominio.PlantillaGasto;
import com.axchisan.gastos.dominio.TipoAsignacion;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.CreditoRepository;
import com.axchisan.gastos.repositorio.CuotaCreditoRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.GastoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MetaAhorroRepository;
import com.axchisan.gastos.repositorio.PlantillaGastoRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.axchisan.gastos.sueldo.PagoProyectado;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * «Mi plan»: cuánto sobra del sueldo cada mes después de pagar todo, y cuándo se alcanza cada
 * meta de ahorro con lo que se aparte.
 *
 * <p>Para cada mes presupuestal: lo que entra (el sueldo del mes; si el mes aún no existe, el
 * que proyecta la fuente en dólares con la TRM de hoy), los gastos fijos (los del mes o, si no
 * existe, las plantillas), las cuotas de créditos según su cuadro, las cuotas de las deudas
 * según su plan, y el gasto del día a día. Lo que queda es lo que se puede ahorrar.
 *
 * <p>Del mes en curso solo cuenta lo que falta: el disponible de hoy menos lo pendiente y la
 * parte del día a día que queda hasta el cierre.
 */
@Service
public class ServicioPlan {

    public static final int MESES_POR_DEFECTO = 12;
    public static final int MESES_MAXIMOS = 24;

    /** Meses cerrados con los que se estima el día a día. */
    private static final int MESES_PARA_ESTIMAR = 3;

    private final UsuarioRepository usuarios;
    private final MesPresupuestalRepository meses;
    private final GastoRepository gastos;
    private final PlantillaGastoRepository plantillas;
    private final CreditoRepository creditos;
    private final CuotaCreditoRepository cuotas;
    private final DeudaRepository deudas;
    private final MetaAhorroRepository metas;
    private final CompraRepository compras;
    private final ServicioSueldo sueldo;
    private final ServicioResumen resumen;

    public ServicioPlan(UsuarioRepository usuarios, MesPresupuestalRepository meses,
                        GastoRepository gastos, PlantillaGastoRepository plantillas,
                        CreditoRepository creditos, CuotaCreditoRepository cuotas,
                        DeudaRepository deudas, MetaAhorroRepository metas,
                        CompraRepository compras, ServicioSueldo sueldo,
                        ServicioResumen resumen) {
        this.usuarios = usuarios;
        this.meses = meses;
        this.gastos = gastos;
        this.plantillas = plantillas;
        this.creditos = creditos;
        this.cuotas = cuotas;
        this.deudas = deudas;
        this.metas = metas;
        this.compras = compras;
        this.sueldo = sueldo;
        this.resumen = resumen;
    }

    public enum Origen { CREDITO, DEUDA }

    /** Una cuota que vence en el mes. */
    public record Pago(Origen origen, UUID id, String nombre, BigDecimal monto, LocalDate fecha) {
    }

    /**
     * @param actual          si es el mes en curso: entonces solo cuenta lo que falta
     * @param ingresoEstimado si el ingreso es una estimación (sueldo en dólares aún no recibido)
     * @param sobra           lo que queda; negativo si no alcanza
     */
    public record MesPlan(YearMonth periodo, boolean actual, BigDecimal ingreso,
                          boolean ingresoEstimado, BigDecimal fijos, List<Pago> pagos,
                          BigDecimal totalPagos, BigDecimal diario, BigDecimal sobra) {
    }

    public record Aporte(YearMonth periodo, BigDecimal monto, BigDecimal acumulado) {
    }

    /**
     * @param aporteMensual       lo que se aparta cada mes según la meta (monto fijo o porcentaje
     *                            de lo que sobra)
     * @param alcanzaEn           mes en que se completa apartando eso; null si no alcanza en el
     *                            horizonte
     * @param alcanzaEnConTodo    mes en que se completaría apartando todo lo que sobra
     */
    public record MetaPlan(UUID id, String nombre, BigDecimal objetivo, BigDecimal ahorrado,
                           BigDecimal faltan, TipoAsignacion tipoAsignacion, BigDecimal valor,
                           BigDecimal aporteMensual, YearMonth alcanzaEn,
                           YearMonth alcanzaEnConTodo, List<Aporte> aportes) {
    }

    /**
     * @param gastoDiario          el que se usó: el del usuario o el estimado
     * @param gastoDiarioEstimado  lo que gastó al mes en el día a día (mediana de los últimos
     *                             meses cerrados)
     * @param sobraPromedio        lo que sobra en promedio en los meses siguientes al actual
     */
    public record Plan(LocalDate hoy, BigDecimal gastoDiario, BigDecimal gastoDiarioEstimado,
                       boolean gastoDiarioPropio, BigDecimal sobraPromedio, List<MesPlan> meses,
                       List<MetaPlan> metas) {
    }

    @Transactional(readOnly = true)
    public Plan de(UUID usuarioId, LocalDate hoy, int cantidad) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));
        int n = Math.max(1, Math.min(cantidad, MESES_MAXIMOS));
        YearMonth actual = ServicioInicio.periodoDe(hoy);

        BigDecimal estimado = gastoDiarioEstimado(usuarioId, actual);
        boolean propio = usuario.getPlanGastoDiario() != null;
        BigDecimal diario = propio ? usuario.getPlanGastoDiario() : estimado;

        Map<YearMonth, BigDecimal> sueldos = sueldosProyectados(usuarioId, actual, n);
        Map<YearMonth, List<Pago>> pagos = pagosPorMes(usuarioId, actual, n);
        BigDecimal fijosPlantilla = plantillas.listarActivas(usuarioId).stream()
                .map(PlantillaGasto::getMontoDefault)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<MesPlan> lista = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            YearMonth periodo = actual.plusMonths(i);
            List<Pago> delMes = pagos.getOrDefault(periodo, List.of());
            Optional<MesPresupuestal> mes = meses.buscarPorPeriodo(usuarioId,
                    (short) periodo.getYear(), (short) periodo.getMonthValue());
            lista.add(i == 0
                    ? mesActual(usuarioId, mes, periodo, hoy, diario, pagosDelPeriodo(pagos,
                            periodo))
                    : mesFuturo(usuarioId, mes, periodo, diario, delMes, sueldos,
                            fijosPlantilla));
        }

        BigDecimal sobraPromedio = lista.size() <= 1 ? lista.getFirst().sobra()
                : lista.subList(1, lista.size()).stream().map(MesPlan::sobra)
                        .reduce(BigDecimal.ZERO, BigDecimal::add)
                        .divide(BigDecimal.valueOf(lista.size() - 1L), 0, RoundingMode.DOWN);

        return new Plan(hoy, diario, estimado, propio, sobraPromedio, lista,
                planDeMetas(usuarioId, lista));
    }

    /** Guarda el gasto del día a día del usuario; null vuelve a la estimación. */
    @Transactional
    public void fijarGastoDiario(UUID usuarioId, BigDecimal monto) {
        if (monto != null && monto.signum() < 0) {
            throw new IllegalArgumentException("El gasto del día a día no puede ser negativo");
        }
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));
        usuario.setPlanGastoDiario(monto == null ? null : monto.setScale(2, RoundingMode.HALF_UP));
    }

    // --- los meses ---

    private MesPlan mesActual(UUID usuarioId, Optional<MesPresupuestal> mes, YearMonth periodo,
                              LocalDate hoy, BigDecimal diario, List<Pago> pagosDelMes) {
        // Del día a día solo falta la parte de los días que quedan hasta el 27.
        LocalDate inicio = ServicioInicio.vencimientoEn(periodo, 28);
        LocalDate fin = ServicioInicio.vencimientoEn(periodo.plusMonths(1), 28).minusDays(1);
        long dias = ChronoUnit.DAYS.between(inicio, fin) + 1;
        long quedan = Math.max(0, ChronoUnit.DAYS.between(hoy, fin) + 1);
        BigDecimal diarioRestante = diario.multiply(BigDecimal.valueOf(quedan))
                .divide(BigDecimal.valueOf(dias), 0, RoundingMode.HALF_UP);

        if (mes.isEmpty()) {
            BigDecimal total = suma(pagosDelMes);
            return new MesPlan(periodo, true, BigDecimal.ZERO, false, BigDecimal.ZERO,
                    pagosDelMes, total, diarioRestante,
                    total.add(diarioRestante).negate());
        }
        ResumenMensual r = resumen.del(usuarioId, mes.get().getId());
        // Solo las cuotas que vencen antes del cierre: las del 4 del mes siguiente ya son del
        // siguiente mes (y allí se cuentan).
        BigDecimal cuotasPendientes = suma(pagosDelMes);
        BigDecimal sobra = r.disponibleHoy().subtract(r.gastoPendiente())
                .subtract(cuotasPendientes).subtract(diarioRestante);
        return new MesPlan(periodo, true, r.disponibleHoy(), false, r.gastoPendiente(),
                pagosDelMes, cuotasPendientes, diarioRestante, sobra);
    }

    private MesPlan mesFuturo(UUID usuarioId, Optional<MesPresupuestal> mes, YearMonth periodo,
                              BigDecimal diario, List<Pago> pagosDelMes,
                              Map<YearMonth, BigDecimal> sueldos, BigDecimal fijosPlantilla) {
        BigDecimal ingreso;
        boolean estimado;
        BigDecimal fijos;
        if (mes.isPresent()) {
            MesPresupuestal m = mes.get();
            ingreso = m.getIngresoBase();
            estimado = m.isSueldoAutomatico();
            fijos = gastos.listarDelMes(m.getId()).stream().map(Gasto::getMonto)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
        } else {
            ingreso = sueldos.getOrDefault(periodo, BigDecimal.ZERO);
            estimado = ingreso.signum() > 0;
            fijos = fijosPlantilla;
        }
        BigDecimal totalPagos = suma(pagosDelMes);
        BigDecimal sobra = ingreso.subtract(fijos).subtract(totalPagos).subtract(diario);
        return new MesPlan(periodo, false, ingreso, estimado, fijos, pagosDelMes, totalPagos,
                diario, sobra);
    }

    /** Las cuotas sin pagar que vencen entre el 28 y el 27 del mes presupuestal. */
    private static List<Pago> pagosDelPeriodo(Map<YearMonth, List<Pago>> pagos,
                                              YearMonth periodo) {
        LocalDate inicio = ServicioInicio.vencimientoEn(periodo, 28);
        LocalDate fin = ServicioInicio.vencimientoEn(periodo.plusMonths(1), 28).minusDays(1);
        return pagos.values().stream().flatMap(List::stream)
                .filter(p -> !p.fecha().isBefore(inicio) && !p.fecha().isAfter(fin))
                .sorted(Comparator.comparing(Pago::fecha))
                .toList();
    }

    /** Lo que trae cada fuente de ingreso en cada mes presupuestal, en pesos. */
    private Map<YearMonth, BigDecimal> sueldosProyectados(UUID usuarioId, YearMonth actual,
                                                         int n) {
        Map<YearMonth, BigDecimal> resultado = new HashMap<>();
        for (FuenteIngreso fuente : sueldo.listar(usuarioId)) {
            if (!fuente.isActivo()) {
                continue;
            }
            // Desde el mes anterior: el pago de un mes cae en el presupuesto del siguiente.
            for (PagoProyectado p : sueldo.proyeccion(usuarioId, fuente.getId(),
                    actual.minusMonths(1), n + 2)) {
                YearMonth periodo = p.mesPresupuestal() != null ? p.mesPresupuestal()
                        : ServicioInicio.periodoDe(p.primerDiaPosible());
                resultado.merge(periodo, p.montoPesos(), BigDecimal::add);
            }
        }
        return resultado;
    }

    /**
     * Las cuotas de cada mes: las de los créditos según su cuadro, y las de las deudas según su
     * plan (cuota mensual con su interés, o pago único en la fecha límite), igual que en el
     * panorama de deudas. Se cruzan con el mes calendario, como en el resumen.
     */
    private Map<YearMonth, List<Pago>> pagosPorMes(UUID usuarioId, YearMonth actual, int n) {
        Map<YearMonth, List<Pago>> resultado = new LinkedHashMap<>();
        YearMonth hasta = actual.plusMonths(n - 1L);

        for (Credito credito : creditos.listarDelUsuario(usuarioId)) {
            if (!credito.isActivo()) {
                continue;
            }
            for (CuotaCredito q : cuotas.listarDelCredito(credito.getId())) {
                YearMonth mes = YearMonth.from(q.getFecha());
                if (q.isPagada() || mes.isBefore(actual.minusMonths(1)) || mes.isAfter(hasta)) {
                    continue;
                }
                resultado.computeIfAbsent(mes, k -> new ArrayList<>()).add(new Pago(
                        Origen.CREDITO, credito.getId(),
                        "Cuota " + q.getNumero() + " · " + credito.getEntidad(),
                        q.getValorCuota(), q.getFecha()));
            }
        }

        for (Deuda deuda : deudas.listarActivas(usuarioId)) {
            if (deuda.isAFavor() || deuda.getSaldo().signum() <= 0) {
                continue;
            }
            BigDecimal cuota = deuda.getCuotaSugerida();
            LocalDate limite = deuda.getFechaLimite();
            boolean conCuota = cuota != null && cuota.signum() > 0;
            if (!conCuota && limite == null) {
                continue; // Sin plan no se sabe cuándo se paga.
            }
            BigDecimal tasa = deuda.getTasaInteresMensual() == null ? BigDecimal.ZERO
                    : deuda.getTasaInteresMensual().divide(BigDecimal.valueOf(100), 8,
                            RoundingMode.HALF_UP);
            YearMonth primero = limite != null && !YearMonth.from(limite).isBefore(actual)
                    ? YearMonth.from(limite) : actual.plusMonths(1);
            int dia = limite != null ? limite.getDayOfMonth() : 1;
            BigDecimal restante = deuda.getSaldo();
            for (YearMonth mes = primero; !mes.isAfter(hasta) && restante.signum() > 0;
                 mes = mes.plusMonths(1)) {
                BigDecimal conInteres = restante.add(restante.multiply(tasa))
                        .setScale(2, RoundingMode.HALF_UP);
                BigDecimal pago = conCuota ? cuota.min(conInteres) : conInteres;
                restante = conInteres.subtract(pago);
                resultado.computeIfAbsent(mes, k -> new ArrayList<>()).add(new Pago(
                        Origen.DEUDA, deuda.getId(), deuda.getAcreedor(), pago,
                        mes.atDay(Math.min(dia, mes.lengthOfMonth()))));
            }
        }
        resultado.values().forEach(l -> l.sort(Comparator.comparing(Pago::fecha)));
        return resultado;
    }

    /**
     * Lo que se gasta al mes en el día a día: la mediana de las compras al contado de los
     * últimos meses cerrados. La mediana y no el promedio, para que un mes raro (una mudanza)
     * no lo infle.
     */
    BigDecimal gastoDiarioEstimado(UUID usuarioId, YearMonth actual) {
        List<BigDecimal> totales = new ArrayList<>();
        for (int i = 1; i <= MESES_PARA_ESTIMAR; i++) {
            YearMonth p = actual.minusMonths(i);
            meses.buscarPorPeriodo(usuarioId, (short) p.getYear(), (short) p.getMonthValue())
                    .map(m -> compras.totalInmediatoDelMes(m.getId()))
                    .filter(t -> t.signum() > 0)
                    .ifPresent(totales::add);
        }
        if (totales.isEmpty()) {
            return BigDecimal.ZERO;
        }
        totales.sort(Comparator.naturalOrder());
        int medio = totales.size() / 2;
        BigDecimal mediana = totales.size() % 2 == 1 ? totales.get(medio)
                : totales.get(medio - 1).add(totales.get(medio))
                        .divide(BigDecimal.valueOf(2), 2, RoundingMode.HALF_UP);
        // Redondeado a miles: es una estimación, no una cifra contable.
        return mediana.divide(BigDecimal.valueOf(1000), 0, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(1000));
    }

    // --- las metas ---

    /**
     * Reparte lo que sobra cada mes entre las metas con monto objetivo, por prioridad. Una meta
     * de monto fijo aparta esa cifra (si alcanza); una de porcentaje, esa parte del ingreso o
     * de lo que sobra, según el tipo.
     * El mes en curso no aporta: lo que queda en él es el colchón hasta el próximo sueldo.
     */
    private List<MetaPlan> planDeMetas(UUID usuarioId, List<MesPlan> lista) {
        List<MetaAhorro> conObjetivo = metas.listarActivas(usuarioId).stream()
                .filter(m -> m.getMetaMonto() != null && m.getMetaMonto().signum() > 0)
                .sorted(Comparator.comparingInt(MetaAhorro::getPrioridad))
                .toList();
        Map<UUID, BigDecimal> acumulado = new HashMap<>();
        Map<UUID, List<Aporte>> aportes = new HashMap<>();
        Map<UUID, YearMonth> alcanza = new HashMap<>();
        conObjetivo.forEach(m -> {
            acumulado.put(m.getId(), m.getSaldoAcumulado());
            aportes.put(m.getId(), new ArrayList<>());
            if (m.getSaldoAcumulado().compareTo(m.getMetaMonto()) >= 0) {
                alcanza.put(m.getId(), lista.getFirst().periodo());
            }
        });

        for (MesPlan mes : lista.subList(1, lista.size())) {
            BigDecimal disponible = mes.sobra().max(BigDecimal.ZERO);
            for (MetaAhorro m : conObjetivo) {
                BigDecimal faltan = m.getMetaMonto().subtract(acumulado.get(m.getId()))
                        .max(BigDecimal.ZERO);
                BigDecimal base = m.getTipoAsignacion() == TipoAsignacion.PORCENTAJE_INGRESO
                        ? mes.ingreso() : mes.sobra().max(BigDecimal.ZERO);
                BigDecimal quiere = m.getTipoAsignacion() == TipoAsignacion.MONTO_FIJO
                        ? m.getValor()
                        : base.multiply(m.getValor())
                                .divide(BigDecimal.valueOf(100), 0, RoundingMode.DOWN);
                BigDecimal aporte = quiere.min(disponible).min(faltan);
                disponible = disponible.subtract(aporte);
                BigDecimal nuevo = acumulado.get(m.getId()).add(aporte);
                acumulado.put(m.getId(), nuevo);
                aportes.get(m.getId()).add(new Aporte(mes.periodo(), aporte, nuevo));
                if (!alcanza.containsKey(m.getId()) && nuevo.compareTo(m.getMetaMonto()) >= 0) {
                    alcanza.put(m.getId(), mes.periodo());
                }
            }
        }

        List<MetaPlan> resultado = new ArrayList<>();
        for (MetaAhorro m : conObjetivo) {
            BigDecimal faltan = m.getMetaMonto().subtract(m.getSaldoAcumulado())
                    .max(BigDecimal.ZERO);
            List<Aporte> lasDeEsta = aportes.get(m.getId());
            BigDecimal aporteMensual = lasDeEsta.isEmpty() ? BigDecimal.ZERO
                    : lasDeEsta.getFirst().monto();
            resultado.add(new MetaPlan(m.getId(), m.getNombre(), m.getMetaMonto(),
                    m.getSaldoAcumulado(), faltan, m.getTipoAsignacion(), m.getValor(),
                    aporteMensual, alcanza.get(m.getId()), conTodo(lista, faltan), lasDeEsta));
        }
        return resultado;
    }

    /** El mes en que se juntaría lo que falta apartando todo lo que sobra desde el siguiente. */
    private static YearMonth conTodo(List<MesPlan> lista, BigDecimal faltan) {
        if (faltan.signum() <= 0) {
            return lista.getFirst().periodo();
        }
        BigDecimal junto = BigDecimal.ZERO;
        for (MesPlan mes : lista.subList(1, lista.size())) {
            junto = junto.add(mes.sobra().max(BigDecimal.ZERO));
            if (junto.compareTo(faltan) >= 0) {
                return mes.periodo();
            }
        }
        return null;
    }

    private static BigDecimal suma(List<Pago> pagos) {
        return pagos.stream().map(Pago::monto).reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
