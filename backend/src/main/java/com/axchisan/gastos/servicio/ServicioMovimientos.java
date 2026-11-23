package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.AbonoDeuda;
import com.axchisan.gastos.dominio.Compra;
import com.axchisan.gastos.dominio.CuotaCredito;
import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.Ingreso;
import com.axchisan.gastos.dominio.MedioPago;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.MovimientoAhorro;
import com.axchisan.gastos.dominio.OrigenGasto;
import com.axchisan.gastos.dominio.PagoRecibido;
import com.axchisan.gastos.dominio.TipoIngreso;
import com.axchisan.gastos.dominio.TipoMovimientoAhorro;
import com.axchisan.gastos.repositorio.AbonoDeudaRepository;
import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.CuotaCreditoRepository;
import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
import com.axchisan.gastos.repositorio.GastoRepository;
import com.axchisan.gastos.repositorio.IngresoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MovimientoAhorroRepository;
import com.axchisan.gastos.repositorio.PagoRecibidoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Todo lo que entró y salió en un mes, en una sola lista.
 *
 * <p>Antes había que mirar cuatro sitios para saber a dónde se fue el dinero: el mes (sueldo,
 * ingresos y gastos fijos), el día a día, las deudas y los créditos. Aquí se juntan con las mismas
 * reglas que usa el resumen, de modo que lo que suma la lista es exactamente el disponible del mes.
 */
@Service
public class ServicioMovimientos {

    private final MesPresupuestalRepository meses;
    private final IngresoRepository ingresos;
    private final GastoRepository gastos;
    private final CompraRepository compras;
    private final AbonoDeudaRepository abonos;
    private final CuotaCreditoRepository cuotas;
    private final MovimientoAhorroRepository ahorro;
    private final FuenteIngresoRepository fuentes;
    private final PagoRecibidoRepository pagosRecibidos;
    private final ServicioResumen resumen;

    public ServicioMovimientos(MesPresupuestalRepository meses, IngresoRepository ingresos,
                               GastoRepository gastos, CompraRepository compras,
                               AbonoDeudaRepository abonos, CuotaCreditoRepository cuotas,
                               MovimientoAhorroRepository ahorro, FuenteIngresoRepository fuentes,
                               PagoRecibidoRepository pagosRecibidos, ServicioResumen resumen) {
        this.meses = meses;
        this.ingresos = ingresos;
        this.gastos = gastos;
        this.compras = compras;
        this.abonos = abonos;
        this.cuotas = cuotas;
        this.ahorro = ahorro;
        this.fuentes = fuentes;
        this.pagosRecibidos = pagosRecibidos;
        this.resumen = resumen;
    }

    /** De dónde sale cada movimiento: decide qué se puede hacer con él en la app. */
    public enum TipoMovimiento { SUELDO, INGRESO, GASTO, COMPRA, ABONO, CUOTA, AHORRO, TARJETA }

    /**
     * Una línea de la lista.
     *
     * @param id          del ingreso, gasto, compra, abono, cuota o movimiento de ahorro; en el
     *                    sueldo, la fuente (o null si es el sueldo puesto a mano)
     * @param categoria   la categoría del gasto o de la compra, o el tipo del ingreso
     * @param monto       positivo si entra, negativo si sale
     * @param cuenta      si suma al disponible del mes; una compra a crédito sale después
     * @param etiqueta    marca breve: FIJO, PRESTAMO, CREDITO
     * @param detalle     una frase corta bajo el título: «Se paga el 4 dic», «Falta $20.000»
     */
    public record Movimiento(TipoMovimiento tipo, UUID id, LocalDate fecha, String titulo,
                             String categoria, BigDecimal monto, boolean cuenta, String etiqueta,
                             String detalle, String notas, OffsetDateTime creado) {
    }

    /** Un gasto del mes con algo por pagar. */
    public record PorPagar(UUID id, String nombre, String categoria, BigDecimal monto,
                           BigDecimal pendiente, LocalDate vence, boolean fijo) {
    }

    /**
     * @param entro  sueldo e ingresos ya cobrados (igual que en el resumen)
     * @param salio  todo lo que ya salió del bolsillo
     * @param queda  el disponible del mes: {@code entro − salio}
     */
    public record MovimientosDelMes(UUID mesId, YearMonth periodo, boolean cerrado,
                                    BigDecimal entro, BigDecimal salio, BigDecimal queda,
                                    List<PorPagar> porPagar, List<Movimiento> movimientos) {
    }

    @Transactional(readOnly = true)
    public MovimientosDelMes del(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = meses.buscarDelUsuario(usuarioId, mesId)
                .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));
        ResumenMensual r = resumen.del(usuarioId, mesId);
        YearMonth periodo = mes.periodo();
        LocalDate inicio = ServicioInicio.vencimientoEn(periodo, 28);

        List<Movimiento> lista = new ArrayList<>();
        lista.addAll(sueldo(usuarioId, mes, inicio));
        lista.addAll(ingresosCobrados(mesId));
        List<PorPagar> porPagar = new ArrayList<>();
        lista.addAll(gastosPagados(mes, inicio, porPagar));
        lista.addAll(comprasDelMes(mesId));
        lista.addAll(abonosDelMes(mesId));
        lista.addAll(cuotasPagadas(usuarioId, periodo));
        lista.addAll(movimientosDeAhorro(mesId));
        lista.addAll(tarjetasPagadas(usuarioId, periodo));

        lista.sort(Comparator.comparing(Movimiento::fecha).reversed()
                .thenComparing(Movimiento::creado,
                        Comparator.nullsLast(Comparator.reverseOrder())));
        porPagar.sort(Comparator.comparing(PorPagar::vence,
                Comparator.nullsLast(Comparator.naturalOrder())).thenComparing(PorPagar::nombre));

        BigDecimal entro = r.ingresoTotal();
        return new MovimientosDelMes(mesId, periodo, mes.isCerrado(), entro,
                entro.subtract(r.disponibleHoy()), r.disponibleHoy(), porPagar, lista);
    }

    /**
     * El sueldo base del mes. Si llegó por un pago anotado («Ya me llegó»), sale con su fecha;
     * lo que no se explique con pagos anotados aparece al empezar el mes.
     */
    private List<Movimiento> sueldo(UUID usuarioId, MesPresupuestal mes, LocalDate inicio) {
        List<Movimiento> resultado = new ArrayList<>();
        BigDecimal restante = mes.getIngresoBase();
        if (restante.signum() <= 0) {
            return resultado;
        }
        for (FuenteIngreso fuente : fuentes.listarDelUsuario(usuarioId)) {
            for (PagoRecibido pago : pagosRecibidos.deLaFuente(fuente.getId())) {
                if (!ServicioInicio.periodoDe(pago.getFecha()).equals(mes.periodo())
                        || pago.getMontoPesos().compareTo(restante) > 0) {
                    continue;
                }
                restante = restante.subtract(pago.getMontoPesos());
                resultado.add(new Movimiento(TipoMovimiento.SUELDO, fuente.getId(),
                        pago.getFecha(), "Sueldo " + fuente.getNombre(), "SUELDO",
                        pago.getMontoPesos(), true, null,
                        pago.getMontoOriginal().stripTrailingZeros().toPlainString() + " "
                                + fuente.getMoneda(),
                        null, pago.getCreatedAt()));
            }
        }
        if (restante.signum() > 0) {
            resultado.add(new Movimiento(TipoMovimiento.SUELDO, null, inicio, "Sueldo del mes",
                    "SUELDO", restante, true, null, null, null, null));
        }
        return resultado;
    }

    private List<Movimiento> ingresosCobrados(UUID mesId) {
        return ingresos.listarDelMes(mesId).stream()
                .filter(Ingreso::isRecibido)
                .map(i -> new Movimiento(TipoMovimiento.INGRESO, i.getId(), i.getFecha(),
                        i.getConcepto(), i.getTipo().name(), i.getMonto(), true,
                        i.getTipo() == TipoIngreso.PRESTAMO ? "PRESTAMO" : null, null,
                        i.getNotas(), i.getCreatedAt()))
                .toList();
    }

    /**
     * Lo pagado de cada gasto va a la lista en la fecha del pago; lo que falta, a «por pagar».
     * Un gasto en cero (como el transporte de un mes sin pasajes) no aparece en ninguno.
     */
    private List<Movimiento> gastosPagados(MesPresupuestal mes, LocalDate inicio,
                                           List<PorPagar> porPagar) {
        List<Movimiento> resultado = new ArrayList<>();
        for (Gasto g : gastos.listarDelMes(mes.getId())) {
            boolean fijo = g.getPlantillaId() != null || g.getOrigen() == OrigenGasto.PLANTILLA;
            BigDecimal pendiente = g.saldoPendiente();
            if (pendiente.signum() > 0) {
                porPagar.add(new PorPagar(g.getId(), g.getNombre(), g.getCategoria().name(),
                        g.getMonto(), pendiente,
                        g.getDiaVencimiento() == null
                                ? null
                                : ServicioInicio.vencimientoEn(mes.periodo(),
                                        g.getDiaVencimiento()),
                        fijo));
            }
            if (g.getMontoPagado().signum() > 0) {
                resultado.add(new Movimiento(TipoMovimiento.GASTO, g.getId(),
                        g.getFechaPago() != null ? g.getFechaPago() : inicio, g.getNombre(),
                        g.getCategoria().name(), g.getMontoPagado().negate(), true,
                        fijo ? "FIJO" : null,
                        pendiente.signum() > 0 ? "Pagado en parte" : null, g.getNotas(),
                        g.getCreatedAt()));
            }
        }
        return resultado;
    }

    /** Las compras del día a día. Las de crédito se ven, pero salen cuando vence el corte. */
    private List<Movimiento> comprasDelMes(UUID mesId) {
        return compras.listarDelMes(mesId).stream()
                .map((Compra c) -> {
                    boolean credito = c.getMedio() == MedioPago.CREDITO;
                    String detalle = credito
                            ? (c.getTarjeta() == null ? "A crédito" : c.getTarjeta().getNombre())
                                    + " · se paga el " + ServicioInicio.diaYMes(c.vencimiento())
                            : c.getMedio() == MedioPago.DEBITO ? "Débito" : "Efectivo";
                    return new Movimiento(TipoMovimiento.COMPRA, c.getId(), c.getFecha(),
                            c.getDescripcion(), c.getCategoria().name(), c.getMonto().negate(),
                            !credito, credito ? "CREDITO" : null, detalle, c.getNota(),
                            c.getCreatedAt());
                })
                .toList();
    }

    private List<Movimiento> abonosDelMes(UUID mesId) {
        return abonos.listarDelMes(mesId).stream()
                .map((AbonoDeuda a) -> new Movimiento(TipoMovimiento.ABONO, a.getId(),
                        a.getFecha(), "Pago a " + a.getDeuda().getAcreedor(), "DEUDA",
                        a.getMonto().negate(), true, null, null, a.getNota(), a.getCreatedAt()))
                .toList();
    }

    /** Como en el resumen, las cuotas se cruzan con el mes calendario, no el presupuestal. */
    private List<Movimiento> cuotasPagadas(UUID usuarioId, YearMonth periodo) {
        return cuotas.pagadasEntre(usuarioId, periodo.atDay(1), periodo.atEndOfMonth()).stream()
                .map((CuotaCredito q) -> new Movimiento(TipoMovimiento.CUOTA, q.getId(),
                        q.getFechaPago() != null ? q.getFechaPago() : q.getFecha(),
                        "Cuota " + q.getNumero() + " · " + q.getCredito().getEntidad(), "DEUDA",
                        (q.getMontoPagado() != null ? q.getMontoPagado() : q.getValorCuota())
                                .negate(),
                        true, null, "Crédito · cuota " + q.getNumero() + " de "
                                + q.getCredito().getPlazoCuotas(),
                        null, null))
                .toList();
    }

    private List<Movimiento> movimientosDeAhorro(UUID mesId) {
        return ahorro.listarDelMes(mesId).stream()
                .map((MovimientoAhorro m) -> {
                    boolean aporte = m.getTipo() == TipoMovimientoAhorro.APORTE;
                    return new Movimiento(TipoMovimiento.AHORRO, m.getId(), m.getFecha(),
                            (aporte ? "Ahorro · " : "Retiro · ") + m.getMeta().getNombre(),
                            "AHORRO", aporte ? m.getMonto().negate() : m.getMonto(), true, null,
                            null, m.getNota(), m.getCreatedAt());
                })
                .toList();
    }

    /** Lo que se pagó este mes de compras a crédito de meses anteriores, por tarjeta. */
    private List<Movimiento> tarjetasPagadas(UUID usuarioId, YearMonth periodo) {
        Map<String, List<Compra>> porTarjeta = new LinkedHashMap<>();
        for (Compra c : compras.cortesDe(usuarioId, (short) periodo.getYear(),
                (short) periodo.getMonthValue())) {
            if (c.isPagado()) {
                String nombre = c.getTarjeta() == null ? "la tarjeta" : c.getTarjeta().getNombre();
                porTarjeta.computeIfAbsent(nombre, k -> new ArrayList<>()).add(c);
            }
        }
        List<Movimiento> resultado = new ArrayList<>();
        porTarjeta.forEach((nombre, lista) -> {
            BigDecimal total = lista.stream().map(Compra::getMonto)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            LocalDate fecha = lista.getFirst().vencimiento();
            resultado.add(new Movimiento(TipoMovimiento.TARJETA, null, fecha,
                    "Pago de " + nombre, "DEUDA", total.negate(), true, null,
                    lista.size() == 1 ? "1 compra" : lista.size() + " compras", null, null));
        });
        return resultado;
    }
}
