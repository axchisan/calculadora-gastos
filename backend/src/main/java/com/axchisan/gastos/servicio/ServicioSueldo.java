package com.axchisan.gastos.servicio;

import com.axchisan.gastos.calendario.CalculadoraFestivos;
import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.MedioCobro;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import com.axchisan.gastos.sueldo.CalculadoraSueldo;
import com.axchisan.gastos.sueldo.PagoProyectado;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Ingresos en otra moneda: sus condiciones, sus pagos esperados y su paso al presupuesto. */
@Service
public class ServicioSueldo {

    private final FuenteIngresoRepository fuentes;
    private final UsuarioRepository usuarios;
    private final CalculadoraFestivos festivos;
    private final ServicioMeses meses;

    public ServicioSueldo(FuenteIngresoRepository fuentes, UsuarioRepository usuarios,
                          CalculadoraFestivos festivos, ServicioMeses meses) {
        this.fuentes = fuentes;
        this.usuarios = usuarios;
        this.festivos = festivos;
        this.meses = meses;
    }

    @Transactional(readOnly = true)
    public List<FuenteIngreso> listar(UUID usuarioId) {
        return fuentes.listarDelUsuario(usuarioId);
    }

    @Transactional(readOnly = true)
    public FuenteIngreso buscar(UUID usuarioId, UUID fuenteId) {
        return fuentes.buscarDelUsuario(usuarioId, fuenteId)
                .orElseThrow(() -> new RecursoNoEncontrado("el ingreso", fuenteId));
    }

    /** Datos editables de una fuente; los nulos se dejan como estaban. */
    public record Cambios(String nombre, BigDecimal montoMensual, LocalDate fechaInicio,
                          LocalDate fechaFin, Boolean quitarFechaFin, MedioCobro medio,
                          String cuentaDestino, Integer diasHabilesPago, Integer diasTolerancia,
                          BigDecimal trm, LocalDate trmFecha, BigDecimal comisionPorcentaje,
                          BigDecimal comisionFija, BigDecimal descuentoCambioPorcentaje,
                          BigDecimal costoRetiro, Boolean activo, String notas) {
    }

    @Transactional
    public FuenteIngreso crear(UUID usuarioId, Cambios datos) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));
        if (datos.nombre() == null || datos.montoMensual() == null || datos.fechaInicio() == null
                || datos.trm() == null) {
            throw new IllegalArgumentException(
                    "Faltan datos: nombre, monto mensual, fecha de inicio y TRM son obligatorios");
        }
        FuenteIngreso fuente = new FuenteIngreso(usuario, datos.nombre(), datos.montoMensual(),
                datos.fechaInicio(), datos.trm(),
                datos.trmFecha() != null ? datos.trmFecha() : LocalDate.now());
        // Al crearla se parte de los costos típicos del medio; después se pueden afinar.
        fuente.usarCostosTipicosDe(datos.medio() != null ? datos.medio() : MedioCobro.TRANSFERENCIA);
        aplicar(fuente, new Cambios(null, null, null, datos.fechaFin(), null, null,
                datos.cuentaDestino(), datos.diasHabilesPago(), datos.diasTolerancia(), null, null,
                datos.comisionPorcentaje(), datos.comisionFija(),
                datos.descuentoCambioPorcentaje(), datos.costoRetiro(), datos.activo(),
                datos.notas()));
        return fuentes.save(fuente);
    }

    @Transactional
    public FuenteIngreso actualizar(UUID usuarioId, UUID fuenteId, Cambios cambios) {
        FuenteIngreso fuente = buscar(usuarioId, fuenteId);
        // Cambiar de medio arrastra sus costos típicos; si en la misma petición llegan costos
        // concretos, esos mandan porque se aplican después.
        if (cambios.medio() != null && cambios.medio() != fuente.getMedio()) {
            fuente.usarCostosTipicosDe(cambios.medio());
        }
        aplicar(fuente, cambios);
        return fuentes.save(fuente);
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID fuenteId) {
        fuentes.delete(buscar(usuarioId, fuenteId));
    }

    /** Los próximos pagos a partir del mes indicado (o del actual). */
    @Transactional(readOnly = true)
    public List<PagoProyectado> proyeccion(UUID usuarioId, UUID fuenteId, YearMonth desde,
                                           int cantidad) {
        FuenteIngreso fuente = buscar(usuarioId, fuenteId);
        return CalculadoraSueldo.proyectar(fuente.condiciones(),
                desde != null ? desde : YearMonth.now(), Math.max(1, Math.min(cantidad, 24)),
                festivos::esNoLaborable);
    }

    /**
     * Lleva los pagos proyectados al sueldo base de cada mes presupuestal.
     *
     * <p>Los meses que no existen se crean. Los cerrados no se tocan: son historia y su ingreso
     * ya es el que de verdad fue.
     *
     * @return los meses actualizados con su nuevo sueldo base
     */
    @Transactional
    public Map<YearMonth, BigDecimal> llevarAlPresupuesto(UUID usuarioId, UUID fuenteId,
                                                          YearMonth desde, int cantidad) {
        Map<YearMonth, BigDecimal> porMes = new LinkedHashMap<>();
        for (PagoProyectado pago : proyeccion(usuarioId, fuenteId, desde, cantidad)) {
            porMes.merge(pago.mesPresupuestal(), pago.montoPesos(), BigDecimal::add);
        }

        Map<YearMonth, BigDecimal> aplicados = new LinkedHashMap<>();
        porMes.forEach((periodo, monto) -> {
            MesPresupuestal mes = meses.obtenerOCrear(usuarioId, periodo);
            if (mes.isCerrado()) {
                return;
            }
            meses.actualizarIngreso(usuarioId, mes.getId(), monto);
            aplicados.put(periodo, monto);
        });
        return aplicados;
    }

    private static void aplicar(FuenteIngreso f, Cambios c) {
        if (c.nombre() != null) {
            f.setNombre(c.nombre());
        }
        if (c.montoMensual() != null) {
            if (c.montoMensual().signum() <= 0) {
                throw new IllegalArgumentException("El monto mensual debe ser mayor que cero");
            }
            f.setMontoMensual(c.montoMensual());
        }
        if (c.fechaInicio() != null) {
            f.setFechaInicio(c.fechaInicio());
        }
        if (Boolean.TRUE.equals(c.quitarFechaFin())) {
            f.setFechaFin(null);
        } else if (c.fechaFin() != null) {
            f.setFechaFin(c.fechaFin());
        }
        if (f.getFechaFin() != null && f.getFechaFin().isBefore(f.getFechaInicio())) {
            throw new IllegalArgumentException("La fecha de fin no puede ser anterior al inicio");
        }
        if (c.cuentaDestino() != null) {
            f.setCuentaDestino(c.cuentaDestino().isBlank() ? null : c.cuentaDestino());
        }
        if (c.diasHabilesPago() != null) {
            if (c.diasHabilesPago() < 1 || c.diasHabilesPago() > 20) {
                throw new IllegalArgumentException("Los días hábiles de pago van de 1 a 20");
            }
            f.setDiasHabilesPago(c.diasHabilesPago().shortValue());
        }
        if (c.diasTolerancia() != null) {
            if (c.diasTolerancia() < 0 || c.diasTolerancia() > 10) {
                throw new IllegalArgumentException("La tolerancia va de 0 a 10 días hábiles");
            }
            f.setDiasTolerancia(c.diasTolerancia().shortValue());
        }
        if (c.trm() != null) {
            f.actualizarTrm(c.trm(), c.trmFecha());
        }
        if (c.comisionPorcentaje() != null) {
            f.setComisionPorcentaje(noNegativo(c.comisionPorcentaje()));
        }
        if (c.comisionFija() != null) {
            f.setComisionFija(noNegativo(c.comisionFija()));
        }
        if (c.descuentoCambioPorcentaje() != null) {
            f.setDescuentoCambioPorcentaje(noNegativo(c.descuentoCambioPorcentaje()));
        }
        if (c.costoRetiro() != null) {
            f.setCostoRetiro(noNegativo(c.costoRetiro()));
        }
        if (c.activo() != null) {
            f.setActivo(c.activo());
        }
        if (c.notas() != null) {
            f.setNotas(c.notas().isBlank() ? null : c.notas());
        }
    }

    private static BigDecimal noNegativo(BigDecimal valor) {
        if (valor.signum() < 0) {
            throw new IllegalArgumentException("Los costos no pueden ser negativos");
        }
        return valor;
    }
}
