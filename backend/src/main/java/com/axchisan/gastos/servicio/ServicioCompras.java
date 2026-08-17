package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.Compra;
import com.axchisan.gastos.dominio.MedioPago;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.OrigenCompra;
import com.axchisan.gastos.dominio.Tarjeta;
import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.TarjetaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Las compras del día a día.
 *
 * <p>El registro es deliberadamente ligero: una compra se apunta y ya está. Nada de estados ni
 * de abonos. Si esto costara más de unos segundos, dejaría de apuntarse a los tres días y el
 * apartado no serviría de nada.
 */
@Service
public class ServicioCompras {

    private final CompraRepository compras;
    private final MesPresupuestalRepository meses;
    private final TarjetaRepository tarjetas;

    public ServicioCompras(CompraRepository compras, MesPresupuestalRepository meses,
                           TarjetaRepository tarjetas) {
        this.compras = compras;
        this.meses = meses;
        this.tarjetas = tarjetas;
    }

    @Transactional(readOnly = true)
    public List<Compra> listarDelMes(UUID usuarioId, UUID mesId) {
        mesDelUsuario(usuarioId, mesId);
        return compras.listarDelMes(mesId);
    }

    @Transactional(readOnly = true)
    public Compra buscar(UUID usuarioId, UUID compraId) {
        return compras.buscarDelUsuario(usuarioId, compraId)
                .orElseThrow(() -> new RecursoNoEncontrado("la compra", compraId));
    }

    @Transactional
    public Compra registrar(UUID usuarioId, UUID mesId, LocalDate fecha, String descripcion,
                            CategoriaGasto categoria, BigDecimal monto, MedioPago medio,
                            UUID tarjetaId, String nota, OrigenCompra origen) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        if (mes.isCerrado()) {
            throw new ServicioMeses.MesCerrado(mes.periodo());
        }

        LocalDate cuando = fecha == null ? LocalDate.now() : fecha;
        exigirQueLaFechaCaigaEnElMes(mes, cuando);

        Compra compra = new Compra(mes, cuando, descripcion, categoria, monto);
        compra.aplicarMedio(medio == null ? MedioPago.EFECTIVO : medio,
                tarjetaId == null ? null : tarjetaDelUsuario(usuarioId, tarjetaId));
        compra.setNota(nota);
        compra.setOrigen(origen == null ? OrigenCompra.MANUAL : origen);
        return compras.save(compra);
    }

    @Transactional
    public Compra actualizar(UUID usuarioId, UUID compraId, LocalDate fecha, String descripcion,
                             CategoriaGasto categoria, BigDecimal monto, MedioPago medio,
                             UUID tarjetaId, String nota) {
        Compra compra = buscar(usuarioId, compraId);
        exigirMesAbierto(compra);

        if (descripcion != null) {
            compra.setDescripcion(descripcion);
        }
        if (categoria != null) {
            compra.setCategoria(categoria);
        }
        if (monto != null) {
            compra.setMonto(monto);
        }
        if (fecha != null) {
            exigirQueLaFechaCaigaEnElMes(compra.getMes(), fecha);
            compra.cambiarFecha(fecha);
        }
        if (nota != null) {
            compra.setNota(nota);
        }
        // El medio se aplica al final porque recalcula el mes de pago, y para eso necesita la
        // fecha ya actualizada.
        if (medio != null) {
            compra.aplicarMedio(medio,
                    tarjetaId == null ? null : tarjetaDelUsuario(usuarioId, tarjetaId));
        }
        return compras.save(compra);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID compraId) {
        Compra compra = buscar(usuarioId, compraId);
        exigirMesAbierto(compra);
        compras.delete(compra);
    }

    // --- cortes de tarjeta ---

    /**
     * Lo que hay que pagar de tarjetas de crédito en un periodo, desglosado por tarjeta.
     *
     * <p>El corte que vence en octubre reúne compras hechas en agosto y en septiembre, así que
     * no se puede sacar mirando un solo mes.
     */
    @Transactional(readOnly = true)
    public List<CorteTarjeta> cortesDe(UUID usuarioId, YearMonth periodo) {
        List<Compra> delPeriodo = compras.cortesDe(usuarioId,
                (short) periodo.getYear(), (short) periodo.getMonthValue());

        List<CorteTarjeta> cortes = new ArrayList<>();
        for (Tarjeta tarjeta : tarjetas.listarDeCredito(usuarioId)) {
            List<Compra> suyas = delPeriodo.stream()
                    .filter(c -> c.getTarjeta() != null
                            && c.getTarjeta().getId().equals(tarjeta.getId()))
                    .toList();
            if (suyas.isEmpty()) {
                continue;
            }
            BigDecimal total = suyas.stream()
                    .map(Compra::getMonto)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal pendiente = suyas.stream()
                    .filter(c -> !c.isPagado())
                    .map(Compra::getMonto)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            cortes.add(new CorteTarjeta(tarjeta, periodo,
                    tarjeta.getDiaPago() == null ? null : periodo.atDay(tarjeta.getDiaPago()),
                    total, pendiente, suyas));
        }
        return cortes;
    }

    /**
     * Marca como pagado, o devuelve a pendiente, todo el corte de una tarjeta.
     *
     * <p>Un corte se paga entero: el banco no cobra compra por compra.
     */
    @Transactional
    public void saldarCorte(UUID usuarioId, UUID tarjetaId, YearMonth periodo, boolean pagado) {
        Tarjeta tarjeta = tarjetaDelUsuario(usuarioId, tarjetaId);

        List<Compra> delCorte = compras.cortesDe(usuarioId,
                        (short) periodo.getYear(), (short) periodo.getMonthValue()).stream()
                .filter(c -> c.getTarjeta() != null
                        && c.getTarjeta().getId().equals(tarjeta.getId()))
                .toList();

        if (delCorte.isEmpty()) {
            throw new RecursoNoEncontrado(
                    "no hay compras de " + tarjeta.getNombre() + " que venzan en " + periodo);
        }
        delCorte.forEach(c -> c.marcarPagado(pagado));
        compras.saveAll(delCorte);
    }

    /** Un corte de tarjeta: lo que vence en un mes por lo comprado en meses anteriores. */
    public record CorteTarjeta(Tarjeta tarjeta, YearMonth periodo, LocalDate vencimiento,
                               BigDecimal total, BigDecimal pendiente, List<Compra> compras) {

        public boolean estaSaldado() {
            return pendiente.signum() == 0;
        }
    }

    // --- utilidades ---

    private MesPresupuestal mesDelUsuario(UUID usuarioId, UUID mesId) {
        return meses.buscarDelUsuario(usuarioId, mesId)
                .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));
    }

    private Tarjeta tarjetaDelUsuario(UUID usuarioId, UUID tarjetaId) {
        return tarjetas.buscarDelUsuario(usuarioId, tarjetaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la tarjeta", tarjetaId));
    }

    private void exigirMesAbierto(Compra compra) {
        if (compra.getMes().isCerrado()) {
            throw new ServicioMeses.MesCerrado(compra.getMes().periodo());
        }
    }

    /**
     * Una compra tiene que caer dentro del mes en el que se registra.
     *
     * <p>Sin esto sería fácil apuntar en agosto algo comprado en septiembre, y el mes de pago
     * saldría mal sin que nada avisara.
     */
    private void exigirQueLaFechaCaigaEnElMes(MesPresupuestal mes, LocalDate fecha) {
        if (!YearMonth.from(fecha).equals(mes.periodo())) {
            throw new IllegalArgumentException(
                    "La compra es del " + fecha + " y el mes es " + mes.periodo());
        }
    }
}
