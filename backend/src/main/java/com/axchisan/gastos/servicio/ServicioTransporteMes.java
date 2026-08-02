package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.ConfigTransporteMes;
import com.axchisan.gastos.dominio.DiaTransporteMes;
import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.dominio.OrigenGasto;
import com.axchisan.gastos.repositorio.ConfigTransporteMesRepository;
import com.axchisan.gastos.repositorio.DiaTransporteMesRepository;
import com.axchisan.gastos.repositorio.GastoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.transporte.CalculadoraTransporte;
import com.axchisan.gastos.transporte.ConfiguracionTransporte;
import com.axchisan.gastos.transporte.DiaTransporte;
import com.axchisan.gastos.transporte.ResumenTransporte;
import com.axchisan.gastos.transporte.TipoDia;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.YearMonth;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Une el motor de cálculo de transporte con la persistencia.
 *
 * <p>El motor ({@link CalculadoraTransporte}) es puro y no conoce la base de datos; este servicio
 * carga los datos, lo invoca y guarda el resultado, manteniendo además sincronizado el gasto del
 * mes que refleja el total.
 */
@Service
public class ServicioTransporteMes {

    /** Nombre del gasto que refleja el resultado del cálculo dentro del presupuesto. */
    private static final String NOMBRE_GASTO = "Transporte";

    private final ConfigTransporteMesRepository configuraciones;
    private final DiaTransporteMesRepository dias;
    private final GastoRepository gastos;
    private final MesPresupuestalRepository meses;
    private final CalculadoraTransporte calculadora;

    public ServicioTransporteMes(ConfigTransporteMesRepository configuraciones,
                                 DiaTransporteMesRepository dias, GastoRepository gastos,
                                 MesPresupuestalRepository meses,
                                 CalculadoraTransporte calculadora) {
        this.configuraciones = configuraciones;
        this.dias = dias;
        this.gastos = gastos;
        this.meses = meses;
        this.calculadora = calculadora;
    }

    /**
     * Prepara el transporte de un mes recién creado.
     *
     * <p>Hereda los parámetros del mes anterior si lo hay: la tarifa del pasaje y la rutina de
     * karate rara vez cambian de un mes a otro, así que es mejor punto de partida que los valores
     * por defecto.
     */
    @Transactional
    public ConfigTransporteMes inicializar(MesPresupuestal mes, BigDecimal valorPasaje,
                                           MesPresupuestal anterior) {
        ConfigTransporteMes previa = anterior == null ? null
                : configuraciones.buscarDelMes(anterior.getId()).orElse(null);

        BigDecimal tarifa = valorPasaje != null ? valorPasaje
                : previa != null ? previa.getValorPasaje() : BigDecimal.ZERO;

        ConfigTransporteMes config = new ConfigTransporteMes(mes, tarifa);
        if (previa != null) {
            config.setPasajesDiaOficina(previa.getPasajesDiaOficina());
            config.setPasajesExtraKarate(previa.getPasajesExtraKarate());
            config.setPasajesKarateDesdeCasa(previa.getPasajesKarateDesdeCasa());
            config.setDiasLaborales(previa.getDiasLaborales());
            config.setDiasKarate(previa.getDiasKarate());
            config.setDiasRemotosPorSemana(previa.getDiasRemotosPorSemana());
        }
        configuraciones.save(config);
        regenerarDias(mes, config);
        return config;
    }

    /** Descarta la clasificación actual y vuelve a proponerla desde cero. */
    @Transactional
    public ResumenTransporte regenerar(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        ServicioMeses.verificarAbierto(mes);
        ConfigTransporteMes config = configDelMes(mes);
        regenerarDias(mes, config);
        return recalcular(mes, config);
    }

    /** Recalcula los pasajes respetando los ajustes manuales del usuario. */
    @Transactional
    public ResumenTransporte recalcular(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        return recalcular(mes, configDelMes(mes));
    }

    @Transactional(readOnly = true)
    public ResumenTransporte resumen(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        ConfigTransporteMes config = configDelMes(mes);
        return calculadora.calcular(mes.periodo(), config.aConfiguracionDeCalculo(),
                diasDeCalculo(mesId));
    }

    /** Proyecciones optimista, esperada y pesimista del mes. */
    @Transactional(readOnly = true)
    public CalculadoraTransporte.Escenarios escenarios(UUID usuarioId, UUID mesId) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        ConfigTransporteMes config = configDelMes(mes);
        return calculadora.escenarios(mes.periodo(), config.aConfiguracionDeCalculo(),
                config.getDiasRemotosPorSemana());
    }

    @Transactional(readOnly = true)
    public ConfigTransporteMes configuracion(UUID usuarioId, UUID mesId) {
        return configDelMes(mesDelUsuario(usuarioId, mesId));
    }

    @Transactional(readOnly = true)
    public List<DiaTransporteMes> dias(UUID usuarioId, UUID mesId) {
        mesDelUsuario(usuarioId, mesId);
        return dias.listarDelMes(mesId);
    }

    /**
     * Cambia los parámetros del mes y vuelve a calcular.
     *
     * @param regenerarClasificacion si además hay que reasignar qué días son remotos; cambiar la
     *                               tarifa no debería descartar los ajustes hechos en el calendario
     */
    @Transactional
    public ResumenTransporte actualizarConfiguracion(
            UUID usuarioId, UUID mesId, BigDecimal valorPasaje, Integer pasajesDiaOficina,
            Integer pasajesExtraKarate, Integer pasajesKarateDesdeCasa,
            Set<DayOfWeek> diasLaborales, Set<DayOfWeek> diasKarate, Integer diasRemotosPorSemana,
            boolean regenerarClasificacion) {

        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        ServicioMeses.verificarAbierto(mes);
        ConfigTransporteMes config = configDelMes(mes);

        if (valorPasaje != null) {
            config.setValorPasaje(valorPasaje);
        }
        if (pasajesDiaOficina != null) {
            config.setPasajesDiaOficina(pasajesDiaOficina.shortValue());
        }
        if (pasajesExtraKarate != null) {
            config.setPasajesExtraKarate(pasajesExtraKarate.shortValue());
        }
        if (pasajesKarateDesdeCasa != null) {
            config.setPasajesKarateDesdeCasa(pasajesKarateDesdeCasa.shortValue());
        }
        if (diasLaborales != null && !diasLaborales.isEmpty()) {
            config.setDiasLaborales(diasLaborales);
        }
        if (diasKarate != null) {
            config.setDiasKarate(diasKarate);
        }
        if (diasRemotosPorSemana != null) {
            config.setDiasRemotosPorSemana(diasRemotosPorSemana.shortValue());
        }
        configuraciones.save(config);

        if (regenerarClasificacion) {
            regenerarDias(mes, config);
        } else if (diasKarate != null) {
            // Los días de karate afectan a cada fecha aunque no se reclasifique el calendario.
            ConfiguracionTransporte calculo = config.aConfiguracionDeCalculo();
            dias.listarDelMes(mesId).forEach(dia ->
                    dia.setHayKarate(calculo.tieneKarate(dia.getFecha().getDayOfWeek())));
        }
        return recalcular(mes, config);
    }

    /** Reclasifica un día concreto: marcarlo como remoto, vacaciones, etc. */
    @Transactional
    public ResumenTransporte cambiarTipoDia(UUID usuarioId, UUID mesId, UUID diaId, TipoDia tipo) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        ServicioMeses.verificarAbierto(mes);
        DiaTransporteMes dia = dias.buscarDelUsuario(usuarioId, diaId)
                .orElseThrow(() -> new RecursoNoEncontrado("el día", diaId));
        dia.setTipo(tipo);
        return recalcular(mes, configDelMes(mes));
    }

    /** Fija a mano los pasajes de un día, protegiéndolos de los recálculos. */
    @Transactional
    public ResumenTransporte fijarPasajes(UUID usuarioId, UUID mesId, UUID diaId, int pasajes) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        ServicioMeses.verificarAbierto(mes);
        if (pasajes < 0) {
            throw new IllegalArgumentException("El número de pasajes no puede ser negativo");
        }
        DiaTransporteMes dia = dias.buscarDelUsuario(usuarioId, diaId)
                .orElseThrow(() -> new RecursoNoEncontrado("el día", diaId));
        dia.fijarPasajesManualmente((short) pasajes);
        return recalcular(mes, configDelMes(mes));
    }

    /** Confirma que el día ya transcurrió, para comparar lo presupuestado con lo real. */
    @Transactional
    public ResumenTransporte confirmarDia(UUID usuarioId, UUID mesId, UUID diaId,
                                          boolean confirmado) {
        MesPresupuestal mes = mesDelUsuario(usuarioId, mesId);
        DiaTransporteMes dia = dias.buscarDelUsuario(usuarioId, diaId)
                .orElseThrow(() -> new RecursoNoEncontrado("el día", diaId));
        dia.setConfirmado(confirmado);
        return recalcular(mes, configDelMes(mes));
    }

    // --- interno ---

    private ResumenTransporte recalcular(MesPresupuestal mes, ConfigTransporteMes config) {
        ResumenTransporte resumen = calculadora.calcular(
                mes.periodo(), config.aConfiguracionDeCalculo(), diasDeCalculo(mes.getId()));

        List<DiaTransporteMes> filas = dias.listarDelMes(mes.getId());
        for (int i = 0; i < filas.size() && i < resumen.dias().size(); i++) {
            filas.get(i).aplicar(resumen.dias().get(i));
        }
        sincronizarGasto(mes, resumen.costoTotal());
        return resumen;
    }

    private void regenerarDias(MesPresupuestal mes, ConfigTransporteMes config) {
        dias.borrarDelMes(mes.getId());
        YearMonth periodo = mes.periodo();
        List<DiaTransporte> propuesta = calculadora.generarPropuesta(
                periodo, config.aConfiguracionDeCalculo(), config.getDiasRemotosPorSemana());

        dias.saveAll(propuesta.stream().map(d -> new DiaTransporteMes(mes, d)).toList());

        ResumenTransporte resumen = calculadora.calcular(
                periodo, config.aConfiguracionDeCalculo(), propuesta);
        sincronizarGasto(mes, resumen.costoTotal());
    }

    /**
     * Mantiene el gasto de transporte del mes al día con el total calculado.
     *
     * <p>Se refleja como un gasto más para que aparezca en el presupuesto y en las gráficas de
     * distribución, pero no se edita directamente: su importe siempre proviene del calendario.
     */
    private void sincronizarGasto(MesPresupuestal mes, BigDecimal total) {
        Gasto gasto = gastos.buscarGastoDeTransporte(mes.getId()).orElse(null);
        if (gasto == null) {
            gasto = new Gasto(NOMBRE_GASTO, CategoriaGasto.TRANSPORTE, total,
                    OrigenGasto.TRANSPORTE);
            mes.agregarGasto(gasto);
            meses.save(mes);
        } else {
            gasto.cambiarMonto(total);
            gastos.save(gasto);
        }
    }

    private List<DiaTransporte> diasDeCalculo(UUID mesId) {
        return dias.listarDelMes(mesId).stream().map(DiaTransporteMes::aDiaDeCalculo).toList();
    }

    private ConfigTransporteMes configDelMes(MesPresupuestal mes) {
        return configuraciones.buscarDelMes(mes.getId())
                .orElseThrow(() -> new RecursoNoEncontrado(
                        "la configuración de transporte del mes " + mes.periodo()));
    }

    private MesPresupuestal mesDelUsuario(UUID usuarioId, UUID mesId) {
        return meses.buscarDelUsuario(usuarioId, mesId)
                .orElseThrow(() -> new RecursoNoEncontrado("el mes", mesId));
    }
}
