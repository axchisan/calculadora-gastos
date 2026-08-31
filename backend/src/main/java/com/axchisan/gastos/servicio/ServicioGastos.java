package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.OrigenGasto;
import com.axchisan.gastos.dominio.Compra;
import com.axchisan.gastos.dominio.ConfigTransporteMes;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.OrigenGasto;
import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.ConfigTransporteMesRepository;
import com.axchisan.gastos.repositorio.GastoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Gastos dentro de un mes: alta, edición y control de pagos. */
@Service
public class ServicioGastos {

    private final GastoRepository gastos;
    private final MesPresupuestalRepository meses;
    private final ConfigTransporteMesRepository configuraciones;
    private final CompraRepository compras;

    public ServicioGastos(GastoRepository gastos, MesPresupuestalRepository meses,
                          ConfigTransporteMesRepository configuraciones,
                          CompraRepository compras) {
        this.gastos = gastos;
        this.meses = meses;
        this.configuraciones = configuraciones;
        this.compras = compras;
    }

    @Transactional(readOnly = true)
    public List<Gasto> listar(UUID usuarioId, UUID mesId) {
        mesDelUsuario(usuarioId, mesId);
        return gastos.listarDelMes(mesId);
    }

    @Transactional
    public Gasto crear(UUID usuarioId, UUID mesId, String nombre, CategoriaGasto categoria,
                       BigDecimal monto, Short diaVencimiento, String notas) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        ServicioMeses.verificarAbierto(mes);

        Gasto gasto = new Gasto(nombre, categoria, monto, OrigenGasto.MANUAL);
        gasto.setDiaVencimiento(diaVencimiento);
        gasto.setNotas(notas);
        mes.agregarGasto(gasto);
        meses.save(mes);
        return gasto;
    }

    @Transactional
    public Gasto actualizar(UUID usuarioId, UUID gastoId, String nombre, CategoriaGasto categoria,
                            BigDecimal monto, Short diaVencimiento, String notas) {
        Gasto gasto = buscar(usuarioId, gastoId);
        ServicioMeses.verificarAbierto(gasto.getMes());
        verificarEditable(gasto);

        if (nombre != null) {
            gasto.setNombre(nombre);
        }
        if (categoria != null) {
            gasto.setCategoria(categoria);
        }
        if (monto != null) {
            gasto.cambiarMonto(monto);
        }
        if (diaVencimiento != null) {
            gasto.setDiaVencimiento(diaVencimiento);
        }
        if (notas != null) {
            gasto.setNotas(notas);
        }
        return gastos.save(gasto);
    }

    /** Marca el gasto como saldado por completo. */
    @Transactional
    public Gasto marcarPagado(UUID usuarioId, UUID gastoId, LocalDate fecha) {
        Gasto gasto = buscar(usuarioId, gastoId);
        ServicioMeses.verificarAbierto(gasto.getMes());
        gasto.marcarPagado(fecha);
        return gastos.save(gasto);
    }

    /** Deshace el pago y devuelve el gasto a pendiente. */
    @Transactional
    public Gasto marcarPendiente(UUID usuarioId, UUID gastoId) {
        Gasto gasto = buscar(usuarioId, gastoId);
        ServicioMeses.verificarAbierto(gasto.getMes());
        gasto.marcarPendiente();
        return gastos.save(gasto);
    }

    /**
     * Corrige cuánto se lleva pagado, sustituyendo el valor en lugar de sumarlo.
     *
     * <p>Es la vía para deshacer un pago apuntado por error o ajustar la cifra cuando no se
     * pagó el total. Se admite también en los gastos que mantiene el sistema, como el de
     * transporte: lo que el calendario calcula es el importe, no si ya se pagó.
     */
    @Transactional
    public Gasto corregirPago(UUID usuarioId, UUID gastoId, BigDecimal montoPagado,
                              LocalDate fecha) {
        Gasto gasto = buscar(usuarioId, gastoId);
        ServicioMeses.verificarAbierto(gasto.getMes());
        gasto.corregirPago(montoPagado, fecha);
        return gastos.save(gasto);
    }

    /**
     * Registra un abono parcial.
     *
     * <p>Si el gasto es el del transporte y el mes tiene configurada una comisión de recarga, se
     * apunta además esa comisión como una compra del día a día. El sistema de recarga la cobra
     * por operación, así que recargar de a poco sale más caro; verla aparecer cada vez es lo que
     * hace visible ese sobrecoste, que de otro modo se pierde.
     */
    @Transactional
    public Gasto abonar(UUID usuarioId, UUID gastoId, BigDecimal importe, LocalDate fecha) {
        Gasto gasto = buscar(usuarioId, gastoId);
        ServicioMeses.verificarAbierto(gasto.getMes());
        gasto.abonar(importe, fecha);

        if (gasto.getOrigen() == OrigenGasto.TRANSPORTE) {
            apuntarComisionDeRecarga(gasto.getMes(), fecha);
        }
        return gastos.save(gasto);
    }

    /** Deja constancia de lo que cobró el sistema de recarga por esta operación. */
    private void apuntarComisionDeRecarga(MesPresupuestal mes, LocalDate fecha) {
        BigDecimal comision = configuraciones.buscarDelMes(mes.getId())
                .map(ConfigTransporteMes::getComisionRecarga)
                .orElse(BigDecimal.ZERO);

        if (comision.signum() <= 0) {
            return;
        }

        LocalDate cuando = fecha == null ? LocalDate.now() : fecha;
        // La comisión pertenece al mes al que se está abonando aunque la recarga se haga a
        // caballo entre dos: es parte del coste de ese transporte, no de otro.
        Compra compra = new Compra(mes, cuando, "Comisión de recarga",
                CategoriaGasto.COMISIONES, comision);
        compras.save(compra);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID gastoId) {
        Gasto gasto = buscar(usuarioId, gastoId);
        ServicioMeses.verificarAbierto(gasto.getMes());
        verificarEditable(gasto);
        gastos.delete(gasto);
    }

    @Transactional(readOnly = true)
    public Gasto buscar(UUID usuarioId, UUID gastoId) {
        return gastos.buscarDelUsuario(usuarioId, gastoId)
                .orElseThrow(() -> new RecursoNoEncontrado("el gasto", gastoId));
    }

    /**
     * Impide editar o borrar los gastos que mantiene el sistema.
     *
     * <p>El de transporte lo calcula el calendario y el de deuda proviene de los abonos:
     * modificarlos aquí dejaría el importe descuadrado respecto de su origen. Marcarlos como
     * pagados sí está permitido, porque eso es información del propio gasto.
     */
    private void verificarEditable(Gasto gasto) {
        if (gasto.getOrigen().esGeneradoPorElSistema()) {
            throw new GastoNoEditable(gasto.getOrigen());
        }
    }

    private MesPresupuestal mesDelUsuario(UUID usuarioId, UUID mesId) {
        return meses.buscarDelUsuario(usuarioId, mesId)
                .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));
    }

    /** El gasto lo gestiona otro módulo y no admite edición directa. */
    public static class GastoNoEditable extends RuntimeException {
        public GastoNoEditable(OrigenGasto origen) {
            super(origen == OrigenGasto.TRANSPORTE
                    ? "El gasto de transporte se modifica desde el calendario del mes"
                    : "El gasto de deuda se modifica desde el módulo de deudas");
        }
    }
}
