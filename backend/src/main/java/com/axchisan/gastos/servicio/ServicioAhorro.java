package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.MetaAhorro;
import com.axchisan.gastos.dominio.MovimientoAhorro;
import com.axchisan.gastos.dominio.TipoAsignacion;
import com.axchisan.gastos.dominio.TipoMovimientoAhorro;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.repositorio.MetaAhorroRepository;
import com.axchisan.gastos.repositorio.MovimientoAhorroRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Metas de ahorro y reparto del dinero disponible. */
@Service
public class ServicioAhorro {

    private final MetaAhorroRepository metas;
    private final MovimientoAhorroRepository movimientos;
    private final UsuarioRepository usuarios;
    private final MesPresupuestalRepository meses;

    public ServicioAhorro(MetaAhorroRepository metas, MovimientoAhorroRepository movimientos,
                          UsuarioRepository usuarios, MesPresupuestalRepository meses) {
        this.metas = metas;
        this.movimientos = movimientos;
        this.usuarios = usuarios;
        this.meses = meses;
    }

    @Transactional(readOnly = true)
    public List<MetaAhorro> listar(UUID usuarioId) {
        return metas.listarDelUsuario(usuarioId);
    }

    @Transactional
    public MetaAhorro crear(UUID usuarioId, String nombre, TipoAsignacion tipoAsignacion,
                            BigDecimal valor, BigDecimal metaMonto, String color, Short prioridad) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));

        validarValor(tipoAsignacion, valor);

        MetaAhorro meta = new MetaAhorro(usuario, nombre, tipoAsignacion, valor);
        meta.setMetaMonto(metaMonto);
        meta.setColor(color);
        if (prioridad != null) {
            meta.setPrioridad(prioridad);
        }
        return metas.save(meta);
    }

    @Transactional
    public MetaAhorro actualizar(UUID usuarioId, UUID metaId, String nombre,
                                 TipoAsignacion tipoAsignacion, BigDecimal valor,
                                 BigDecimal metaMonto, String color, Short prioridad,
                                 Boolean activa) {
        MetaAhorro meta = buscar(usuarioId, metaId);

        TipoAsignacion tipoFinal = tipoAsignacion != null ? tipoAsignacion
                : meta.getTipoAsignacion();
        BigDecimal valorFinal = valor != null ? valor : meta.getValor();
        validarValor(tipoFinal, valorFinal);

        meta.setTipoAsignacion(tipoFinal);
        meta.setValor(valorFinal);
        if (nombre != null) {
            meta.setNombre(nombre);
        }
        if (metaMonto != null) {
            meta.setMetaMonto(metaMonto);
        }
        if (color != null) {
            meta.setColor(color);
        }
        if (prioridad != null) {
            meta.setPrioridad(prioridad);
        }
        if (activa != null) {
            meta.setActiva(activa);
        }
        return metas.save(meta);
    }

    /** Registra un aporte o un retiro y actualiza el saldo de la meta. */
    @Transactional
    public MovimientoAhorro registrarMovimiento(UUID usuarioId, UUID metaId,
                                                TipoMovimientoAhorro tipo, BigDecimal monto,
                                                LocalDate fecha, UUID mesId, String nota) {
        if (monto == null || monto.signum() <= 0) {
            throw new IllegalArgumentException("El monto debe ser mayor que cero");
        }
        MetaAhorro meta = buscar(usuarioId, metaId);
        MesPresupuestal mes = mesId == null ? null
                : meses.buscarDelUsuario(usuarioId, mesId)
                        .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));

        // Lanza si el retiro dejaría la meta en negativo, antes de persistir nada.
        meta.aplicarMovimiento(tipo, monto);
        metas.save(meta);

        MovimientoAhorro movimiento = new MovimientoAhorro(meta, mes, tipo, monto,
                fecha == null ? LocalDate.now() : fecha);
        movimiento.setNota(nota);
        return movimientos.save(movimiento);
    }

    @Transactional
    public void eliminarMovimiento(UUID usuarioId, UUID movimientoId) {
        MovimientoAhorro movimiento = movimientos.buscarDelUsuario(usuarioId, movimientoId)
                .orElseThrow(() -> new RecursoNoEncontrado("el movimiento", movimientoId));

        MetaAhorro meta = movimiento.getMeta();
        // Se aplica el movimiento inverso para devolver el saldo a su estado anterior.
        meta.aplicarMovimiento(
                movimiento.getTipo() == TipoMovimientoAhorro.APORTE
                        ? TipoMovimientoAhorro.RETIRO
                        : TipoMovimientoAhorro.APORTE,
                movimiento.getMonto());
        metas.save(meta);
        movimientos.delete(movimiento);
    }

    @Transactional(readOnly = true)
    public List<MovimientoAhorro> movimientosDe(UUID usuarioId, UUID metaId) {
        buscar(usuarioId, metaId);
        return movimientos.listarDeLaMeta(metaId);
    }

    /**
     * Propone cuánto destinar a cada meta con el dinero de un mes.
     *
     * <p>Se calcula en orden de prioridad, y las metas que reparten un porcentaje del sobrante lo
     * hacen sobre lo que queda tras las anteriores: así, dos metas al 50% del sobrante se llevan
     * el 50% y el 25%, no el 100% entre ambas.
     *
     * @param ingresoTotal ingreso del mes
     * @param disponible   lo que queda tras gastos y deudas
     */
    @Transactional(readOnly = true)
    public List<Asignacion> sugerirDistribucion(UUID usuarioId, BigDecimal ingresoTotal,
                                                BigDecimal disponible) {
        List<Asignacion> asignaciones = new ArrayList<>();
        BigDecimal restante = disponible;

        for (MetaAhorro meta : metas.listarActivas(usuarioId)) {
            BigDecimal aporte = meta.calcularAporte(ingresoTotal, restante);
            // No se reparte más de lo que queda.
            aporte = aporte.min(restante.max(BigDecimal.ZERO));
            if (aporte.signum() > 0) {
                restante = restante.subtract(aporte);
            }
            asignaciones.add(new Asignacion(meta, aporte));
        }
        return asignaciones;
    }

    @Transactional(readOnly = true)
    public MetaAhorro buscar(UUID usuarioId, UUID metaId) {
        return metas.buscarDelUsuario(usuarioId, metaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la meta de ahorro", metaId));
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID metaId) {
        metas.delete(buscar(usuarioId, metaId));
    }

    private void validarValor(TipoAsignacion tipo, BigDecimal valor) {
        if (valor == null || valor.signum() < 0) {
            throw new IllegalArgumentException("El valor de la asignación no puede ser negativo");
        }
        if (tipo != TipoAsignacion.MONTO_FIJO && valor.compareTo(BigDecimal.valueOf(100)) > 0) {
            throw new IllegalArgumentException("Un porcentaje no puede superar el 100%");
        }
    }

    /** Cuánto propone destinar el sistema a una meta concreta. */
    public record Asignacion(MetaAhorro meta, BigDecimal monto) {
    }
}
