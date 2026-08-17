package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.AbonoDeuda;
import com.axchisan.gastos.dominio.Deuda;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.TipoDeuda;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.AbonoDeudaRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

/**
 * Deudas externas y sus abonos.
 *
 * <p>Los abonos <b>no</b> generan un gasto en el mes: se contabilizan directamente desde esta
 * tabla en el resumen mensual. Crear además un gasto los contaría dos veces.
 */
@Service
public class ServicioDeudas {

    private final DeudaRepository deudas;
    private final AbonoDeudaRepository abonos;
    private final UsuarioRepository usuarios;
    private final MesPresupuestalRepository meses;

    public ServicioDeudas(DeudaRepository deudas, AbonoDeudaRepository abonos,
                          UsuarioRepository usuarios, MesPresupuestalRepository meses) {
        this.deudas = deudas;
        this.abonos = abonos;
        this.usuarios = usuarios;
        this.meses = meses;
    }

    @Transactional(readOnly = true)
    public List<Deuda> listar(UUID usuarioId) {
        return deudas.listarDelUsuario(usuarioId);
    }

    @Transactional(readOnly = true)
    public List<Deuda> listarActivas(UUID usuarioId) {
        return deudas.listarActivas(usuarioId);
    }

    /**
     * Las deudas que tenían algo que ver con un mes concreto.
     *
     * <p>Sin filtrar por mes, las deudas saldadas en agosto seguían apareciendo en septiembre y
     * en todos los meses posteriores, donde ya no significan nada.
     */
    @Transactional(readOnly = true)
    public List<Deuda> listarDelPeriodo(UUID usuarioId, YearMonth periodo) {
        return deudas.listarDelMes(usuarioId, periodo.atDay(1), periodo.atEndOfMonth());
    }

    /**
     * Saldo que tenía una deuda al terminar un mes.
     *
     * <p>Al mirar un mes pasado interesa lo que se debía entonces, no lo que se debe hoy: si en
     * agosto se debían 715.887 y se saldaron, agosto debe seguir contando esa cifra.
     */
    @Transactional(readOnly = true)
    public BigDecimal saldoAlCierreDe(UUID deudaId, BigDecimal montoOriginal, YearMonth periodo) {
        BigDecimal abonado = deudas.abonadoHasta(deudaId, periodo.atEndOfMonth());
        return montoOriginal.subtract(abonado).max(BigDecimal.ZERO);
    }

    @Transactional
    public Deuda crear(UUID usuarioId, String acreedor, TipoDeuda tipo, BigDecimal montoOriginal,
                       LocalDate fechaInicio, String descripcion, BigDecimal tasaInteresMensual,
                       BigDecimal cuotaSugerida, LocalDate fechaLimite) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));

        Deuda deuda = new Deuda(usuario, acreedor, tipo, montoOriginal,
                fechaInicio == null ? LocalDate.now() : fechaInicio);
        deuda.setDescripcion(descripcion);
        deuda.setTasaInteresMensual(tasaInteresMensual);
        deuda.setCuotaSugerida(cuotaSugerida);
        deuda.setFechaLimite(fechaLimite);
        return deudas.save(deuda);
    }

    @Transactional
    public Deuda actualizar(UUID usuarioId, UUID deudaId, String acreedor, TipoDeuda tipo,
                            String descripcion, BigDecimal tasaInteresMensual,
                            BigDecimal cuotaSugerida, LocalDate fechaLimite,
                            BigDecimal montoOriginal) {
        Deuda deuda = buscar(usuarioId, deudaId);

        // Corregir el importe conserva lo ya abonado y recalcula el saldo: lo que cambia es la
        // deuda, no los pagos hechos.
        if (montoOriginal != null) {
            deuda.corregirMontoOriginal(montoOriginal);
        }

        if (acreedor != null) {
            deuda.setAcreedor(acreedor);
        }
        if (tipo != null) {
            deuda.setTipo(tipo);
        }
        if (descripcion != null) {
            deuda.setDescripcion(descripcion);
        }
        if (tasaInteresMensual != null) {
            deuda.setTasaInteresMensual(tasaInteresMensual);
        }
        if (cuotaSugerida != null) {
            deuda.setCuotaSugerida(cuotaSugerida);
        }
        if (fechaLimite != null) {
            deuda.setFechaLimite(fechaLimite);
        }
        return deudas.save(deuda);
    }

    /**
     * Registra un abono y descuenta el saldo.
     *
     * @param mesId mes al que se imputa; puede ser nulo si no se quiere vincular
     */
    @Transactional
    public AbonoDeuda registrarAbono(UUID usuarioId, UUID deudaId, BigDecimal monto,
                                     LocalDate fecha, UUID mesId, String nota) {
        Deuda deuda = buscar(usuarioId, deudaId);
        MesPresupuestal mes = mesId == null ? null
                : meses.buscarDelUsuario(usuarioId, mesId)
                        .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));

        // Lanza si el abono supera el saldo, antes de persistir nada.
        deuda.abonar(monto);
        deudas.save(deuda);

        AbonoDeuda abono = new AbonoDeuda(deuda, mes, monto,
                fecha == null ? LocalDate.now() : fecha);
        abono.setNota(nota);
        return abonos.save(abono);
    }

    /** Elimina un abono y devuelve el importe al saldo de la deuda. */
    @Transactional
    public void eliminarAbono(UUID usuarioId, UUID abonoId) {
        AbonoDeuda abono = abonos.buscarDelUsuario(usuarioId, abonoId)
                .orElseThrow(() -> new RecursoNoEncontrado("el abono", abonoId));

        Deuda deuda = abono.getDeuda();
        deuda.revertirAbono(abono.getMonto());
        deudas.save(deuda);
        abonos.delete(abono);
    }

    @Transactional(readOnly = true)
    public List<AbonoDeuda> abonosDe(UUID usuarioId, UUID deudaId) {
        buscar(usuarioId, deudaId);
        return abonos.listarDeLaDeuda(deudaId);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID deudaId) {
        deudas.delete(buscar(usuarioId, deudaId));
    }

    @Transactional(readOnly = true)
    public Deuda buscar(UUID usuarioId, UUID deudaId) {
        return deudas.buscarDelUsuario(usuarioId, deudaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la deuda", deudaId));
    }
}
