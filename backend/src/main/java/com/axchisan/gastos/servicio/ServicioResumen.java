package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.repositorio.AbonoDeudaRepository;
import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.GastoRepository;
import com.axchisan.gastos.repositorio.IngresoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MetaAhorroRepository;
import com.axchisan.gastos.repositorio.MovimientoAhorroRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Calcula el estado financiero de un mes y la evolución a lo largo del tiempo. */
@Service
public class ServicioResumen {

    private final MesPresupuestalRepository meses;
    private final GastoRepository gastos;
    private final IngresoRepository ingresos;
    private final AbonoDeudaRepository abonos;
    private final DeudaRepository deudas;
    private final MetaAhorroRepository metas;
    private final MovimientoAhorroRepository movimientos;
    private final CompraRepository compras;

    public ServicioResumen(MesPresupuestalRepository meses, GastoRepository gastos,
                           IngresoRepository ingresos, AbonoDeudaRepository abonos,
                           DeudaRepository deudas, MetaAhorroRepository metas,
                           MovimientoAhorroRepository movimientos, CompraRepository compras) {
        this.meses = meses;
        this.gastos = gastos;
        this.ingresos = ingresos;
        this.abonos = abonos;
        this.deudas = deudas;
        this.metas = metas;
        this.movimientos = movimientos;
        this.compras = compras;
    }

    /** Resumen completo de un mes. */
    @Transactional(readOnly = true)
    public ResumenMensual del(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = meses.buscarDelUsuario(usuarioId, mesId)
                .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));
        return calcular(usuarioId, mes);
    }

    @Transactional(readOnly = true)
    public ResumenMensual delPeriodo(UUID usuarioId, YearMonth periodo) {
        MesPresupuestal mes = meses.buscarPorPeriodo(usuarioId, (short) periodo.getYear(),
                        (short) periodo.getMonthValue())
                .orElseThrow(() -> new RecursoNoEncontrado(
                        "el mes " + periodo + " no está registrado"));
        return calcular(usuarioId, mes);
    }

    /**
     * Serie histórica para las gráficas de evolución.
     *
     * @param desde primer periodo a incluir
     */
    @Transactional(readOnly = true)
    public List<ResumenMensual> evolucion(UUID usuarioId, YearMonth desde) {
        return meses.listarDesde(usuarioId, (short) desde.getYear(),
                        (short) desde.getMonthValue()).stream()
                .map(mes -> calcular(usuarioId, mes))
                .toList();
    }

    private ResumenMensual calcular(UUID usuarioId, MesPresupuestal mes) {
        UUID mesId = mes.getId();

        BigDecimal ingresoBase = mes.getIngresoBase();
        BigDecimal extrasCobrados = ingresos.totalRecibidoDelMes(mesId);
        BigDecimal extrasTotales = ingresos.totalPrevistoDelMes(mesId);
        BigDecimal ingresoTotal = ingresoBase.add(extrasCobrados);
        BigDecimal ingresoProyectado = ingresoBase.add(extrasTotales);

        BigDecimal gastoTotal = gastos.totalDelMes(mesId);
        BigDecimal gastoPagado = gastos.totalPagadoDelMes(mesId);
        BigDecimal gastoPendiente = gastoTotal.subtract(gastoPagado);

        // Los abonos a deudas y los movimientos de ahorro se contabilizan desde sus propias
        // tablas, no como gastos del mes: sumarlos en ambos sitios los contaría dos veces.
        BigDecimal abonosDeuda = abonos.totalDelMes(mesId);
        BigDecimal aporteAhorro = movimientos.aporteNetoDelMes(mesId);

        // Las compras del día a día se parten en dos según de dónde salió el dinero. Lo pagado
        // en efectivo o con débito ya salió y pesa en este mes. Lo cargado a una tarjeta de
        // crédito no: ese dinero se va cuando venza el corte, uno o dos meses después, y hasta
        // entonces contarlo aquí falsearía el saldo del mes.
        BigDecimal comprasDelMes = compras.totalDelMes(mesId);
        BigDecimal comprasInmediatas = compras.totalInmediatoDelMes(mesId);
        BigDecimal comprasACredito = compras.totalACreditoDelMes(mesId);

        // La otra cara: lo que se compró a crédito en meses anteriores y vence justo en este.
        short anio = (short) mes.periodo().getYear();
        short numeroMes = (short) mes.periodo().getMonthValue();
        BigDecimal cortesPendientes = compras.cortesPendientesDe(usuarioId, anio, numeroMes);
        BigDecimal cortesPagados = compras.cortesPagadosDe(usuarioId, anio, numeroMes);

        // Todo lo que ya salió del bolsillo durante el mes.
        BigDecimal salidaReal = gastoPagado
                .add(abonosDeuda)
                .add(aporteAhorro)
                .add(comprasInmediatas)
                .add(cortesPagados);

        BigDecimal disponibleHoy = ingresoTotal.subtract(salidaReal);

        BigDecimal saldoProyectado = ingresoProyectado
                .subtract(gastoTotal)
                .subtract(abonosDeuda)
                .subtract(aporteAhorro)
                .subtract(comprasInmediatas)
                .subtract(cortesPagados)
                .subtract(cortesPendientes);

        BigDecimal deudaTotal = deudas.saldoTotal(usuarioId);
        BigDecimal ahorroTotal = metas.saldoTotal(usuarioId);

        // Todo lo que ya tiene destino este mes, se haya pagado o no. Es la cifra que responde
        // a «¿cuánto del sueldo está comprometido?», útil para planificar un mes que aún no ha
        // empezado, donde no hay ningún pago hecho y las cifras de lo pagado son todas cero.
        BigDecimal comprometido = gastoTotal
                .add(abonosDeuda)
                .add(aporteAhorro)
                .add(comprasInmediatas)
                .add(cortesPagados);

        // Las deudas con cuota pactada seguirán pidiendo dinero este mes aunque todavía no se
        // haya abonado nada. Contarlas es lo que permite ver el cupo real del sueldo antes de
        // que el mes ocurra; sin esto, una deuda de un millón no pesaría absolutamente nada en
        // la estimación. Lo mismo vale para el corte de la tarjeta que vence este mes.
        BigDecimal cuotasPendientes = calcularCuotasPendientes(usuarioId, mesId);
        BigDecimal comprometidoConCuotas = comprometido
                .add(cuotasPendientes)
                .add(cortesPendientes);

        BigDecimal porcentajeComprometido = ingresoProyectado.signum() == 0
                ? BigDecimal.ZERO
                : comprometidoConCuotas.multiply(BigDecimal.valueOf(100))
                        .divide(ingresoProyectado, 2, RoundingMode.HALF_UP);

        return new ResumenMensual(
                mesId,
                mes.periodo(),
                mes.isCerrado(),
                ingresoBase,
                extrasCobrados,
                extrasTotales,
                ingresoTotal,
                ingresoProyectado,
                gastoTotal,
                gastoPagado,
                gastoPendiente,
                abonosDeuda,
                aporteAhorro,
                disponibleHoy,
                saldoProyectado,
                deudaTotal,
                ahorroTotal,
                ahorroTotal.subtract(deudaTotal),
                comprometido,
                porcentajeComprometido,
                cuotasPendientes,
                comprometidoConCuotas,
                deudas.contarSinCuota(usuarioId),
                comprasDelMes,
                comprasInmediatas,
                comprasACredito,
                cortesPendientes,
                cortesPagados,
                distribucionPorCategoria(mesId, gastoTotal.add(comprasDelMes)));
    }

    /**
     * Cuánto falta abonar este mes según las cuotas pactadas.
     *
     * <p>Por cada deuda se cuenta lo que resta de su cuota tras los abonos ya hechos este mes, y
     * nunca más que el saldo pendiente: una deuda a la que solo le quedan cincuenta mil no puede
     * reclamar una cuota de doscientos mil.
     */
    private BigDecimal calcularCuotasPendientes(UUID usuarioId, UUID mesId) {
        BigDecimal total = BigDecimal.ZERO;

        for (Object[] fila : deudas.cuotasPrevistas(usuarioId, mesId)) {
            BigDecimal cuota = (BigDecimal) fila[0];
            BigDecimal saldo = (BigDecimal) fila[1];
            BigDecimal abonadoEsteMes = (BigDecimal) fila[2];

            BigDecimal pendiente = cuota.subtract(abonadoEsteMes).max(BigDecimal.ZERO).min(saldo);
            total = total.add(pendiente);
        }
        return total;
    }

    /**
     * Reparto del mes por categoría, juntando los gastos y las compras del día a día.
     *
     * <p>Se suman las dos fuentes porque la pregunta que responde la gráfica es «¿en qué se me
     * va el dinero?», y ahí un mes de antojos cuenta igual que el arriendo. Las compras a
     * crédito se incluyen en el mes en que se hicieron, no en el que se pagan: para entender
     * en qué se gasta, lo que importa es cuándo se compró.
     */
    private List<ResumenMensual.TotalCategoria> distribucionPorCategoria(UUID mesId,
                                                                        BigDecimal total) {
        Map<CategoriaGasto, BigDecimal> sumas = new EnumMap<>(CategoriaGasto.class);

        for (List<Object[]> fuente : List.of(gastos.totalesPorCategoria(mesId),
                compras.totalesPorCategoria(mesId))) {
            for (Object[] fila : fuente) {
                sumas.merge((CategoriaGasto) fila[0], (BigDecimal) fila[1], BigDecimal::add);
            }
        }

        List<ResumenMensual.TotalCategoria> resultado = new ArrayList<>();
        sumas.entrySet().stream()
                .sorted(Map.Entry.<CategoriaGasto, BigDecimal>comparingByValue().reversed())
                .forEach(entrada -> {
                    BigDecimal porcentaje = total.signum() == 0
                            ? BigDecimal.ZERO
                            : entrada.getValue().multiply(BigDecimal.valueOf(100))
                                    .divide(total, 2, RoundingMode.HALF_UP);
                    resultado.add(new ResumenMensual.TotalCategoria(
                            entrada.getKey(), entrada.getValue(), porcentaje));
                });
        return resultado;
    }
}
