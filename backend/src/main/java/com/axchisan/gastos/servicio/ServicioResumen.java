package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.repositorio.AbonoDeudaRepository;
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
import java.util.List;
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

    public ServicioResumen(MesPresupuestalRepository meses, GastoRepository gastos,
                           IngresoRepository ingresos, AbonoDeudaRepository abonos,
                           DeudaRepository deudas, MetaAhorroRepository metas,
                           MovimientoAhorroRepository movimientos) {
        this.meses = meses;
        this.gastos = gastos;
        this.ingresos = ingresos;
        this.abonos = abonos;
        this.deudas = deudas;
        this.metas = metas;
        this.movimientos = movimientos;
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

        BigDecimal disponibleHoy = ingresoTotal
                .subtract(gastoPagado)
                .subtract(abonosDeuda)
                .subtract(aporteAhorro);

        BigDecimal saldoProyectado = ingresoProyectado
                .subtract(gastoTotal)
                .subtract(abonosDeuda)
                .subtract(aporteAhorro);

        BigDecimal deudaTotal = deudas.saldoTotal(usuarioId);
        BigDecimal ahorroTotal = metas.saldoTotal(usuarioId);

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
                distribucionPorCategoria(mesId, gastoTotal));
    }

    private List<ResumenMensual.TotalCategoria> distribucionPorCategoria(UUID mesId,
                                                                        BigDecimal gastoTotal) {
        List<ResumenMensual.TotalCategoria> resultado = new ArrayList<>();
        for (Object[] fila : gastos.totalesPorCategoria(mesId)) {
            CategoriaGasto categoria = (CategoriaGasto) fila[0];
            BigDecimal total = (BigDecimal) fila[1];
            BigDecimal porcentaje = gastoTotal.signum() == 0
                    ? BigDecimal.ZERO
                    : total.multiply(BigDecimal.valueOf(100))
                            .divide(gastoTotal, 2, RoundingMode.HALF_UP);
            resultado.add(new ResumenMensual.TotalCategoria(categoria, total, porcentaje));
        }
        return resultado;
    }
}
