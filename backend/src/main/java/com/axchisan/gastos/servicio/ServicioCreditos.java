package com.axchisan.gastos.servicio;

import com.axchisan.gastos.credito.Amortizacion;
import com.axchisan.gastos.dominio.Credito;
import com.axchisan.gastos.dominio.CuotaCredito;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.CreditoRepository;
import com.axchisan.gastos.repositorio.CuotaCreditoRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Créditos con cuadro de amortización, y las cuentas que permiten decidir sobre ellos. */
@Service
public class ServicioCreditos {

    private final CreditoRepository creditos;
    private final CuotaCreditoRepository cuotas;
    private final UsuarioRepository usuarios;

    public ServicioCreditos(CreditoRepository creditos, CuotaCreditoRepository cuotas,
                            UsuarioRepository usuarios) {
        this.creditos = creditos;
        this.cuotas = cuotas;
        this.usuarios = usuarios;
    }

    @Transactional(readOnly = true)
    public List<Credito> listar(UUID usuarioId) {
        return creditos.listarDelUsuario(usuarioId);
    }

    @Transactional(readOnly = true)
    public Credito buscar(UUID usuarioId, UUID creditoId) {
        return creditos.buscarDelUsuario(usuarioId, creditoId)
                .orElseThrow(() -> new RecursoNoEncontrado("el crédito", creditoId));
    }

    @Transactional(readOnly = true)
    public List<CuotaCredito> cuotasDe(UUID usuarioId, UUID creditoId) {
        buscar(usuarioId, creditoId);
        return cuotas.listarDelCredito(creditoId);
    }

    @Transactional
    public Credito crear(UUID usuarioId, Credito plantilla, List<CuotaCredito> plan) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));

        Credito credito = new Credito(usuario, plantilla.getEntidad(),
                plantilla.getMontoOriginal(), plantilla.getPlazoCuotas());
        credito.setNumeroOperacion(plantilla.getNumeroOperacion());
        credito.setDescripcion(plantilla.getDescripcion());
        credito.setTasaEa(plantilla.getTasaEa());
        credito.setDiaPago(plantilla.getDiaPago());
        credito.setFechaDesembolso(plantilla.getFechaDesembolso());
        credito.setFechaVencimiento(plantilla.getFechaVencimiento());

        plan.forEach(credito::anadirCuota);
        return creditos.save(credito);
    }

    @Transactional
    public CuotaCredito marcarCuota(UUID usuarioId, UUID cuotaId, boolean pagada,
                                    LocalDate fecha, BigDecimal monto) {
        CuotaCredito cuota = cuotas.buscarDelUsuario(usuarioId, cuotaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la cuota", cuotaId));

        if (pagada) {
            cuota.marcarPagada(fecha, monto);
        } else {
            cuota.marcarPendiente();
        }
        return cuotas.save(cuota);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID creditoId) {
        creditos.delete(buscar(usuarioId, creditoId));
    }

    // --- estado ---

    /** Fotografía de por dónde va el crédito. */
    @Transactional(readOnly = true)
    public EstadoCredito estadoDe(UUID usuarioId, UUID creditoId) {
        Credito credito = buscar(usuarioId, creditoId);
        List<CuotaCredito> plan = cuotas.listarDelCredito(creditoId);

        BigDecimal capitalPagado = BigDecimal.ZERO;
        BigDecimal interesPagado = BigDecimal.ZERO;
        BigDecimal totalPagado = BigDecimal.ZERO;
        BigDecimal capitalPendiente = BigDecimal.ZERO;
        BigDecimal interesPendiente = BigDecimal.ZERO;
        BigDecimal totalPendiente = BigDecimal.ZERO;
        int pagadas = 0;
        int vencidas = 0;
        CuotaCredito proxima = null;
        LocalDate hoy = LocalDate.now();

        for (CuotaCredito cuota : plan) {
            if (cuota.isPagada()) {
                pagadas++;
                capitalPagado = capitalPagado.add(cuota.getCapital());
                interesPagado = interesPagado.add(cuota.getInteres());
                totalPagado = totalPagado.add(
                        cuota.getMontoPagado() == null ? cuota.getValorCuota()
                                : cuota.getMontoPagado());
            } else {
                capitalPendiente = capitalPendiente.add(cuota.getCapital());
                interesPendiente = interesPendiente.add(cuota.getInteres());
                totalPendiente = totalPendiente.add(cuota.getValorCuota());
                if (cuota.estaVencida(hoy)) {
                    vencidas++;
                }
                if (proxima == null) {
                    proxima = cuota;
                }
            }
        }

        // El saldo es el que declara la primera cuota sin pagar: viene del propio banco y no de
        // una resta, así que no arrastra las diferencias de redondeo del cuadro.
        BigDecimal saldo = proxima == null ? BigDecimal.ZERO : proxima.getSaldoCapital();

        return new EstadoCredito(credito, plan.size(), pagadas, vencidas, saldo,
                capitalPagado, interesPagado, totalPagado,
                capitalPendiente, interesPendiente, totalPendiente, proxima);
    }

    /**
     * Por dónde va un crédito.
     *
     * @param saldo            capital que se debe hoy, según la primera cuota sin pagar
     * @param interesPendiente lo que se pagará de interés si no se adelanta nada
     */
    public record EstadoCredito(Credito credito, int cuotasTotales, int cuotasPagadas,
                                int cuotasVencidas, BigDecimal saldo,
                                BigDecimal capitalPagado, BigDecimal interesPagado,
                                BigDecimal totalPagado, BigDecimal capitalPendiente,
                                BigDecimal interesPendiente, BigDecimal totalPendiente,
                                CuotaCredito proximaCuota) {

        public int cuotasRestantes() {
            return cuotasTotales - cuotasPagadas;
        }

        public boolean estaSaldado() {
            return cuotasRestantes() == 0;
        }

        /** Qué parte del crédito se lleva pagada, medida en dinero y no en número de cuotas. */
        public BigDecimal porcentajePagado() {
            return Amortizacion.porcentaje(totalPagado, totalPagado.add(totalPendiente));
        }

        /**
         * Cuánto cuesta el crédito por encima de lo prestado.
         *
         * <p>Es la cifra que no se ve en ningún extracto y que explica por qué conviene
         * adelantar: al 76% anual se devuelve más de una vez y media lo recibido.
         */
        public BigDecimal costeTotal() {
            return interesPagado.add(interesPendiente);
        }
    }

    // --- simulación de un abono extraordinario ---

    /** Qué se hace con el dinero que se ahorra al abonar de más. */
    public enum ModoDeAbono {
        /** Se mantienen las cuotas que quedan y baja el importe de cada una. */
        REDUCIR_CUOTA,
        /** Se mantiene el importe de la cuota y el crédito se termina antes. */
        REDUCIR_PLAZO
    }

    /**
     * Qué pasaría si se abonara de más a capital.
     *
     * <p>Es la pregunta que justifica todo el módulo. Al 76% efectivo anual, adelantar no ahorra
     * «una cuota»: ahorra todos los intereses que ese capital habría generado hasta el final del
     * plan, y la diferencia entre las dos formas de aplicarlo es enorme.
     *
     * @throws IllegalArgumentException si el abono no es positivo o supera el saldo
     */
    @Transactional(readOnly = true)
    public SimulacionAbono simular(UUID usuarioId, UUID creditoId, BigDecimal abono,
                                   ModoDeAbono modo) {
        if (abono == null || abono.signum() <= 0) {
            throw new IllegalArgumentException("El abono debe ser mayor que cero");
        }

        EstadoCredito estado = estadoDe(usuarioId, creditoId);
        if (estado.estaSaldado()) {
            throw new IllegalArgumentException("El crédito ya está saldado");
        }
        if (abono.compareTo(estado.saldo()) > 0) {
            throw new IllegalArgumentException(
                    "El abono supera el saldo, que es " + estado.saldo());
        }

        double mensual = estado.credito().tasaMensual();
        int restantes = estado.cuotasRestantes();
        BigDecimal saldoTrasAbono = estado.saldo().subtract(abono);

        // Los cargos fijos —seguro, Mipyme— no dependen del interés y se cobran con cada cuota
        // que siga existiendo. Se toman del propio cuadro en vez de estimarlos.
        List<CuotaCredito> pendientes = cuotas.listarDelCredito(creditoId).stream()
                .filter(c -> !c.isPagada())
                .toList();

        BigDecimal cuotaActual = Amortizacion.cuota(estado.saldo(), mensual, restantes);

        int cuotasNuevas;
        BigDecimal cuotaNueva;
        BigDecimal cargosNuevos;

        if (modo == ModoDeAbono.REDUCIR_PLAZO) {
            cuotasNuevas = saldoTrasAbono.signum() == 0
                    ? 0
                    : Amortizacion.cuotasNecesarias(saldoTrasAbono, mensual, cuotaActual);
            cuotaNueva = cuotaActual;
            // Al desaparecer cuotas se ahorran también sus cargos fijos, que en este plan son
            // decenas de miles al mes. Ignorarlo subestimaría el ahorro real.
            cargosNuevos = sumarCargos(pendientes, cuotasNuevas);
        } else {
            cuotasNuevas = restantes;
            cuotaNueva = Amortizacion.cuota(saldoTrasAbono, mensual, restantes);
            cargosNuevos = sumarCargos(pendientes, restantes);
        }

        BigDecimal interesNuevo = Amortizacion.interesTotal(saldoTrasAbono, mensual, cuotasNuevas);
        BigDecimal cargosActuales = sumarCargos(pendientes, restantes);

        BigDecimal totalActual = estado.totalPendiente();
        BigDecimal totalNuevo = saldoTrasAbono.add(interesNuevo).add(cargosNuevos);

        return new SimulacionAbono(
                abono, modo,
                restantes, cuotaActual, estado.interesPendiente(), totalActual, cargosActuales,
                cuotasNuevas, cuotaNueva, interesNuevo, totalNuevo,
                estado.interesPendiente().subtract(interesNuevo),
                restantes - cuotasNuevas,
                // Lo que deja de salir del bolsillo: lo que se iba a pagar menos lo que se
                // pagará, descontando el propio abono, que también sale.
                totalActual.subtract(totalNuevo).subtract(abono),
                estado.proximaCuota() == null ? null : estado.proximaCuota().getFecha());
    }

    /** Los cargos fijos de las primeras {@code cuantas} cuotas pendientes. */
    private BigDecimal sumarCargos(List<CuotaCredito> pendientes, int cuantas) {
        return pendientes.stream()
                .limit(Math.max(cuantas, 0))
                .map(CuotaCredito::cargos)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * Lo que cambiaría al abonar de más.
     *
     * @param ahorroInteres   intereses que ese capital ya no genera
     * @param cuotasAhorradas cuántas cuotas desaparecen; cero si se eligió bajar la cuota
     * @param ahorroNeto      lo que se deja de pagar en total, descontando el propio abono
     */
    public record SimulacionAbono(BigDecimal abono, ModoDeAbono modo,
                                  int cuotasAntes, BigDecimal cuotaAntes,
                                  BigDecimal interesAntes, BigDecimal totalAntes,
                                  BigDecimal cargosAntes,
                                  int cuotasDespues, BigDecimal cuotaDespues,
                                  BigDecimal interesDespues, BigDecimal totalDespues,
                                  BigDecimal ahorroInteres, int cuotasAhorradas,
                                  BigDecimal ahorroNeto, LocalDate desdeCuando) {

        /** Cuánto se ahorra por cada peso adelantado. */
        public BigDecimal rendimiento() {
            return abono.signum() == 0 ? BigDecimal.ZERO
                    : Amortizacion.porcentaje(ahorroInteres, abono);
        }
    }
}
