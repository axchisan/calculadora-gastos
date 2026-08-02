package com.axchisan.gastos.transporte;

import com.axchisan.gastos.calendario.CalculadoraFestivos;
import com.axchisan.gastos.calendario.Festivo;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Motor de cálculo del gasto mensual en transporte.
 *
 * <p>Parte del calendario real del mes: descuenta fines de semana y festivos colombianos,
 * permite marcar días de trabajo remoto, vacaciones o ausencias, y suma el pasaje adicional
 * de los días con actividades personales.
 *
 * @see <a href="../../../../../../../docs/FESTIVOS-Y-TRANSPORTE.md">Especificación</a>
 */
@Component
public class CalculadoraTransporte {

    /**
     * Orden en que se proponen los días de trabajo remoto. El viernes encabeza la lista por ser
     * el más habitual; los días con karate quedan al final, porque trabajar desde casa esos días
     * ahorra menos (el desplazamiento al karate se mantiene).
     */
    private static final List<DayOfWeek> PREFERENCIA_REMOTO = List.of(
            DayOfWeek.FRIDAY, DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY,
            DayOfWeek.TUESDAY, DayOfWeek.THURSDAY);

    private final CalculadoraFestivos festivos;

    public CalculadoraTransporte(CalculadoraFestivos festivos) {
        this.festivos = festivos;
    }

    /**
     * Genera la propuesta inicial del mes, clasificando cada día y repartiendo los días de
     * trabajo remoto. Es el punto de partida que el usuario ajusta en el calendario.
     *
     * @param diasRemotosPorSemana días de trabajo desde casa previstos por semana
     */
    public List<DiaTransporte> generarPropuesta(
            YearMonth mes, ConfiguracionTransporte config, int diasRemotosPorSemana) {

        // Dos celebraciones pueden caer el mismo día (Sagrado Corazón y San Pedro y San Pablo
        // coinciden en 2025, 2030, 2038...); en ese caso es un solo día festivo con ambos nombres.
        Map<LocalDate, String> festivosDelMes = new HashMap<>();
        for (Festivo f : festivos.delMes(mes)) {
            festivosDelMes.merge(f.fecha(), f.nombre(), (uno, otro) -> uno + " y " + otro);
        }

        Set<DayOfWeek> diasRemotos = elegirDiasRemotos(config, diasRemotosPorSemana);
        List<DiaTransporte> dias = new ArrayList<>(mes.lengthOfMonth());

        for (int d = 1; d <= mes.lengthOfMonth(); d++) {
            LocalDate fecha = mes.atDay(d);
            DayOfWeek diaSemana = fecha.getDayOfWeek();
            String nombreFestivo = festivosDelMes.get(fecha);

            TipoDia tipo;
            if (nombreFestivo != null) {
                tipo = TipoDia.FESTIVO;
            } else if (!config.esDiaLaboral(diaSemana)) {
                tipo = TipoDia.FIN_DE_SEMANA;
            } else if (diasRemotos.contains(diaSemana)) {
                tipo = TipoDia.REMOTO;
            } else {
                tipo = TipoDia.OFICINA;
            }

            boolean hayKarate = config.tieneKarate(diaSemana);
            dias.add(new DiaTransporte(fecha, tipo, hayKarate,
                    calcularPasajes(tipo, hayKarate, config), false, false, nombreFestivo));
        }
        return dias;
    }

    /**
     * Recalcula los pasajes de cada día y agrega el resultado del mes.
     *
     * <p>Los días con {@code overrideManual} conservan el valor fijado por el usuario.
     */
    public ResumenTransporte calcular(
            YearMonth mes, ConfiguracionTransporte config, List<DiaTransporte> dias) {

        List<DiaTransporte> calculados = new ArrayList<>(dias.size());
        int totalPasajes = 0;
        int pasajesGastados = 0;
        int diasOficina = 0;
        int diasRemotos = 0;
        int diasFestivos = 0;
        int diasKarate = 0;

        for (DiaTransporte dia : dias) {
            int pasajes = dia.overrideManual()
                    ? dia.pasajes()
                    : calcularPasajes(dia.tipo(), dia.hayKarate(), config);

            calculados.add(new DiaTransporte(dia.fecha(), dia.tipo(), dia.hayKarate(), pasajes,
                    dia.overrideManual(), dia.confirmado(), dia.nombreFestivo()));

            totalPasajes += pasajes;
            if (dia.confirmado()) {
                pasajesGastados += pasajes;
            }

            switch (dia.tipo()) {
                case OFICINA -> diasOficina++;
                case REMOTO -> diasRemotos++;
                // Solo cuentan los festivos que caen en día laboral: son los que ahorran dinero.
                case FESTIVO -> {
                    if (config.esDiaLaboral(dia.fecha().getDayOfWeek())) {
                        diasFestivos++;
                    }
                }
                default -> { }
            }
            if (dia.hayKarate() && pasajes > 0 && !dia.tipo().impideActividades()) {
                diasKarate++;
            }
        }

        BigDecimal valor = config.valorPasaje();
        return new ResumenTransporte(
                mes,
                List.copyOf(calculados),
                totalPasajes,
                valor.multiply(BigDecimal.valueOf(totalPasajes)),
                diasOficina,
                diasRemotos,
                diasFestivos,
                diasKarate,
                pasajesGastados,
                valor.multiply(BigDecimal.valueOf(pasajesGastados)));
    }

    /**
     * Calcula el mes bajo tres supuestos de trabajo remoto, para conocer el rango en que se
     * moverá el gasto antes de que el mes ocurra.
     *
     * @param remotosEsperados días remotos por semana en el escenario esperado
     */
    public Escenarios escenarios(
            YearMonth mes, ConfiguracionTransporte config, int remotosEsperados) {
        return new Escenarios(
                calcular(mes, config, generarPropuesta(mes, config, remotosEsperados + 1)),
                calcular(mes, config, generarPropuesta(mes, config, remotosEsperados)),
                calcular(mes, config, generarPropuesta(mes, config, 0)));
    }

    /**
     * Pasajes que corresponden a un día.
     *
     * <p>Un día de oficina con karate encadena casa → oficina → karate → casa, de ahí el pasaje
     * adicional. Si ese mismo día se trabaja desde casa, el recorrido se reduce a
     * casa → karate → casa.
     */
    private int calcularPasajes(TipoDia tipo, boolean hayKarate, ConfiguracionTransporte config) {
        if (tipo.impideActividades()) {
            return 0;
        }
        if (tipo.requiereDesplazamientoLaboral()) {
            return config.pasajesDiaOficina() + (hayKarate ? config.pasajesExtraKarate() : 0);
        }
        return hayKarate ? config.pasajesKarateDesdeCasa() : 0;
    }

    /** Elige qué días de la semana se proponen como remotos, por orden de preferencia. */
    private Set<DayOfWeek> elegirDiasRemotos(ConfiguracionTransporte config, int cantidad) {
        if (cantidad <= 0) {
            return EnumSet.noneOf(DayOfWeek.class);
        }
        Set<DayOfWeek> candidatos = new LinkedHashSet<>();
        // Primero los días laborales sin karate: trabajar desde casa esos días ahorra el
        // desplazamiento completo.
        PREFERENCIA_REMOTO.stream()
                .filter(config::esDiaLaboral)
                .filter(d -> !config.tieneKarate(d))
                .forEach(candidatos::add);
        PREFERENCIA_REMOTO.stream()
                .filter(config::esDiaLaboral)
                .forEach(candidatos::add);

        Set<DayOfWeek> elegidos = EnumSet.noneOf(DayOfWeek.class);
        candidatos.stream().limit(cantidad).forEach(elegidos::add);
        return elegidos;
    }

    /**
     * Proyecciones del mes según cuántos días se trabaje desde casa.
     *
     * @param optimista más días remotos de lo habitual
     * @param esperado  el escenario más probable
     * @param pesimista todos los días presenciales
     */
    public record Escenarios(
            ResumenTransporte optimista, ResumenTransporte esperado, ResumenTransporte pesimista) {

        /** Diferencia entre el peor y el mejor escenario. */
        public BigDecimal rango() {
            return pesimista.costoTotal().subtract(optimista.costoTotal());
        }
    }
}
