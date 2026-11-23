package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.Cuenta;
import com.axchisan.gastos.dominio.CuotaCredito;
import com.axchisan.gastos.dominio.Deuda;
import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.PagoRecibido;
import com.axchisan.gastos.repositorio.CuotaCreditoRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.GastoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.sueldo.PagoProyectado;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Lo que necesita la pantalla de Inicio, en una sola consulta.
 *
 * <p>Inicio responde a «¿cuánto tengo?» y «¿qué tengo que pagar pronto?». Pedir el resumen, las
 * cuentas, el sueldo y los créditos por separado encadenaba cuatro peticiones, y la primera del
 * día coincide con el arranque en frío de Lambda: juntarlas es lo que hace que abra al momento.
 */
@Service
public class ServicioInicio {

    /** Hasta dónde mirar los próximos pagos. Un mes cubre el siguiente sueldo y sus cuotas. */
    public static final int DIAS_POR_DELANTE = 30;

    /** El mes presupuestal empieza el día 28 del mes anterior al que le da nombre. */
    private static final int DIA_DE_INICIO_DEL_MES = 28;

    private static final Locale ES_CO = Locale.forLanguageTag("es-CO");

    private final MesPresupuestalRepository meses;
    private final GastoRepository gastos;
    private final CuotaCreditoRepository cuotas;
    private final DeudaRepository deudas;
    private final ServicioResumen resumen;
    private final ServicioCuentas cuentas;
    private final ServicioSueldo sueldo;

    public ServicioInicio(MesPresupuestalRepository meses, GastoRepository gastos,
                          CuotaCreditoRepository cuotas, DeudaRepository deudas,
                          ServicioResumen resumen, ServicioCuentas cuentas,
                          ServicioSueldo sueldo) {
        this.meses = meses;
        this.gastos = gastos;
        this.cuotas = cuotas;
        this.deudas = deudas;
        this.resumen = resumen;
        this.cuentas = cuentas;
        this.sueldo = sueldo;
    }

    /**
     * @param periodo        mes presupuestal en curso
     * @param resumen        su resumen, o null si ese mes aún no se ha creado
     * @param cuentas        las cuentas y el efectivo, con su último saldo
     * @param proximosPagos  lo que vence en los próximos {@link #DIAS_POR_DELANTE} días, lo vencido
     *                       sin pagar y lo pendiente del mes que no tiene día fijo
     */
    public record Inicio(LocalDate hoy, YearMonth periodo, ResumenMensual resumen,
                         List<Cuenta> cuentas, List<ProximoPago> proximosPagos) {
    }

    /** De dónde sale un próximo pago, para que la app sepa a qué pantalla llevar al tocarlo. */
    public enum TipoPago { GASTO, CUOTA_CREDITO, DEUDA, SUELDO }

    /**
     * Algo que hay que pagar (o que va a entrar) pronto.
     *
     * @param id         identificador del gasto, la cuota, la deuda o la fuente de sueldo
     * @param fecha      cuándo vence; null si es un gasto del mes sin día fijo
     * @param fechaHasta último día de la ventana en que puede llegar; solo en el sueldo
     * @param ingreso    true si es dinero que entra
     * @param vencido    la fecha ya pasó y sigue sin pagarse
     */
    public record ProximoPago(TipoPago tipo, UUID id, String titulo, String detalle,
                              LocalDate fecha, LocalDate fechaHasta, BigDecimal monto,
                              boolean ingreso, boolean vencido) {
    }

    @Transactional
    public Inicio de(UUID usuarioId, LocalDate hoy) {
        YearMonth periodo = periodoDe(hoy);
        LocalDate hasta = hoy.plusDays(DIAS_POR_DELANTE);

        Optional<MesPresupuestal> mesActual = buscarMes(usuarioId, periodo);
        ResumenMensual resumenDelMes = mesActual
                .map(m -> resumen.del(usuarioId, m.getId()))
                .orElse(null);

        List<ProximoPago> proximos = new ArrayList<>();
        mesActual.ifPresent(m -> proximos.addAll(gastosPendientes(m, hoy, hasta, true)));
        // Del mes siguiente solo interesa lo que tiene fecha dentro del horizonte: sus gastos sin
        // día fijo llenarían la lista con cosas que aún no tocan.
        buscarMes(usuarioId, periodo.plusMonths(1))
                .ifPresent(m -> proximos.addAll(gastosPendientes(m, hoy, hasta, false)));
        proximos.addAll(cuotasPendientes(usuarioId, hoy, hasta));
        proximos.addAll(deudasConFecha(usuarioId, hoy, hasta));
        proximos.addAll(proximosSueldos(usuarioId, hoy, hasta));
        proximos.sort(ORDEN);

        return new Inicio(hoy, periodo, resumenDelMes, cuentas.listar(usuarioId), proximos);
    }

    /** Mes presupuestal al que pertenece una fecha: del 28 en adelante cuenta ya el siguiente. */
    public static YearMonth periodoDe(LocalDate fecha) {
        YearMonth mes = YearMonth.from(fecha);
        return fecha.getDayOfMonth() >= DIA_DE_INICIO_DEL_MES ? mes.plusMonths(1) : mes;
    }

    /**
     * Fecha en que vence un gasto con día fijo dentro de su mes presupuestal.
     *
     * <p>Noviembre va del 28 de octubre al 27 de noviembre: un gasto que vence «el 30» cae el 30
     * de octubre, y uno que vence «el 4», el 4 de noviembre. En meses cortos el día se ajusta al
     * último que exista.
     */
    public static LocalDate vencimientoEn(YearMonth periodo, int dia) {
        YearMonth calendario = dia >= DIA_DE_INICIO_DEL_MES ? periodo.minusMonths(1) : periodo;
        return calendario.atDay(Math.min(dia, calendario.lengthOfMonth()));
    }

    /** Lo vencido primero, después lo del mes sin fecha y luego por fecha. */
    private static final Comparator<ProximoPago> ORDEN = Comparator
            .comparing((ProximoPago p) -> !p.vencido())
            .thenComparing(p -> p.fecha() != null)
            .thenComparing(ProximoPago::fecha, Comparator.nullsFirst(Comparator.naturalOrder()))
            .thenComparing(ProximoPago::ingreso)
            .thenComparing(ProximoPago::titulo);

    private Optional<MesPresupuestal> buscarMes(UUID usuarioId, YearMonth periodo) {
        return meses.buscarPorPeriodo(usuarioId, (short) periodo.getYear(),
                (short) periodo.getMonthValue());
    }

    private List<ProximoPago> gastosPendientes(MesPresupuestal mes, LocalDate hoy,
                                               LocalDate hasta, boolean incluirSinFecha) {
        List<ProximoPago> resultado = new ArrayList<>();
        for (Gasto gasto : gastos.listarDelMes(mes.getId())) {
            BigDecimal pendiente = gasto.saldoPendiente();
            if (pendiente.signum() <= 0) {
                continue;
            }
            LocalDate fecha = gasto.getDiaVencimiento() == null
                    ? null
                    : vencimientoEn(mes.periodo(), gasto.getDiaVencimiento());
            if (fecha == null ? !incluirSinFecha : fecha.isAfter(hasta)) {
                continue;
            }
            String detalle = gasto.getMontoPagado().signum() > 0
                    ? "Falta una parte"
                    : fecha == null ? "Gasto fijo · este mes" : "Gasto fijo";
            resultado.add(new ProximoPago(TipoPago.GASTO, gasto.getId(), gasto.getNombre(),
                    detalle, fecha, null, pendiente, false,
                    fecha != null && fecha.isBefore(hoy)));
        }
        return resultado;
    }

    private List<ProximoPago> cuotasPendientes(UUID usuarioId, LocalDate hoy, LocalDate hasta) {
        return cuotas.pendientesHasta(usuarioId, hasta).stream()
                .map((CuotaCredito q) -> new ProximoPago(TipoPago.CUOTA_CREDITO, q.getId(),
                        "Cuota " + q.getNumero() + " · " + q.getCredito().getEntidad(),
                        "Crédito · cuota " + q.getNumero() + " de "
                                + q.getCredito().getPlazoCuotas(),
                        q.getFecha(), null, q.getValorCuota(), false,
                        q.getFecha().isBefore(hoy)))
                .toList();
    }

    /**
     * Deudas con fecha límite dentro del horizonte. Se pide la cuota pactada si la hay; si no, lo
     * que queda, porque una deuda con fecha y sin cuota es un pago único.
     */
    private List<ProximoPago> deudasConFecha(UUID usuarioId, LocalDate hoy, LocalDate hasta) {
        List<ProximoPago> resultado = new ArrayList<>();
        for (Deuda deuda : deudas.listarActivas(usuarioId)) {
            LocalDate limite = deuda.getFechaLimite();
            if (limite == null || limite.isAfter(hasta) || deuda.getSaldo().signum() <= 0) {
                continue;
            }
            BigDecimal cuota = deuda.getCuotaSugerida();
            boolean pagoUnico = cuota == null || cuota.compareTo(deuda.getSaldo()) >= 0;
            resultado.add(new ProximoPago(TipoPago.DEUDA, deuda.getId(), deuda.getAcreedor(),
                    pagoUnico ? "Pago único" : "Cuota de la deuda",
                    limite, null, pagoUnico ? deuda.getSaldo() : cuota, false,
                    limite.isBefore(hoy)));
        }
        return resultado;
    }

    /**
     * El próximo pago de cada sueldo que aún no ha llegado.
     *
     * <p>Se proyecta desde el mes anterior porque el pago de este mes puede estar todavía dentro
     * de su ventana, que se estira unos días hábiles. Un pago ya anotado como recibido no sale.
     */
    private List<ProximoPago> proximosSueldos(UUID usuarioId, LocalDate hoy, LocalDate hasta) {
        sueldo.refrescarTrm(usuarioId);
        List<ProximoPago> resultado = new ArrayList<>();
        for (FuenteIngreso fuente : sueldo.listar(usuarioId)) {
            if (!fuente.isActivo()) {
                continue;
            }
            Set<YearMonth> recibidos = sueldo.pagosRecibidos(usuarioId, fuente.getId()).stream()
                    .map(PagoRecibido::getMesDePago)
                    .collect(Collectors.toSet());
            sueldo.proyeccion(usuarioId, fuente.getId(), YearMonth.from(hoy).minusMonths(1), 3)
                    .stream()
                    .filter(p -> !recibidos.contains(p.mesDePago()))
                    .filter(p -> !p.fechaTardia().isBefore(hoy))
                    .filter(p -> !p.primerDiaPosible().isAfter(hasta))
                    .findFirst()
                    .ifPresent(p -> resultado.add(pagoDeSueldo(fuente, p)));
        }
        return resultado;
    }

    private static ProximoPago pagoDeSueldo(FuenteIngreso fuente, PagoProyectado pago) {
        String detalle = String.format(ES_CO, "%,.2f %s", pago.montoOriginal(),
                        fuente.getMoneda())
                + (fuente.getCuentaDestino() == null || fuente.getCuentaDestino().isBlank()
                        ? ""
                        : " · llega a " + fuente.getCuentaDestino());
        return new ProximoPago(TipoPago.SUELDO, fuente.getId(), "Sueldo " + fuente.getNombre(),
                detalle, pago.primerDiaPosible(), pago.fechaLimite(), pago.montoPesos(), true,
                false);
    }
}
