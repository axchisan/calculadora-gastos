package com.axchisan.gastos.calendario;

import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * Calcula los 18 días festivos de Colombia para un año dado.
 *
 * <p>La <b>Ley 51 de 1983</b>, conocida como <i>Ley Emiliani</i>, traslada varios festivos al
 * lunes siguiente para generar puentes. Los festivos de fecha fija de mayor arraigo y los dos
 * días de Semana Santa quedan exceptuados de ese traslado.
 *
 * <p>Son <b>18 celebraciones</b>, pero no siempre 18 días distintos: cuando el 29 de junio cae
 * en domingo, <i>San Pedro y San Pablo</i> se traslada al lunes y coincide con <i>Sagrado
 * Corazón</i>, dejando el año con 17 días festivos. Ocurre en 2019, 2025, 2030, 2038 y 2041.
 * Por eso {@link #delAnio(int)} devuelve las celebraciones y {@link #diasFestivos(int)} las
 * fechas únicas, que es lo que hay que contar para calcular días hábiles.
 *
 * <p>El cálculo es una función pura del año, así que el resultado se memoriza.
 *
 * @see <a href="../../../../../../../docs/FESTIVOS-Y-TRANSPORTE.md">Especificación</a>
 */
@Component
public class CalculadoraFestivos {

    /** Festivos de fecha fija que nunca se trasladan. */
    private static final List<FestivoFijo> FIJOS = List.of(
            new FestivoFijo(1, 1, "Año Nuevo"),
            new FestivoFijo(5, 1, "Día del Trabajo"),
            new FestivoFijo(7, 20, "Día de la Independencia"),
            new FestivoFijo(8, 7, "Batalla de Boyacá"),
            new FestivoFijo(12, 8, "Inmaculada Concepción"),
            new FestivoFijo(12, 25, "Navidad"));

    /** Festivos que la Ley Emiliani traslada al lunes siguiente. */
    private static final List<FestivoFijo> TRASLADABLES = List.of(
            new FestivoFijo(1, 6, "Reyes Magos"),
            new FestivoFijo(3, 19, "San José"),
            new FestivoFijo(6, 29, "San Pedro y San Pablo"),
            new FestivoFijo(8, 15, "Asunción de la Virgen"),
            new FestivoFijo(10, 12, "Día de la Raza"),
            new FestivoFijo(11, 1, "Todos los Santos"),
            new FestivoFijo(11, 11, "Independencia de Cartagena"));

    /**
     * Festivos derivados de la Pascua, con su desplazamiento en días.
     *
     * <p>Jueves y Viernes Santo se celebran en su día litúrgico. Ascensión, Corpus Christi y
     * Sagrado Corazón sí se trasladan, y los desplazamientos +43, +64 y +71 ya incorporan ese
     * traslado al lunes (sus fechas litúrgicas son +39, +60 y +68).
     */
    private static final List<FestivoPascua> DE_PASCUA = List.of(
            new FestivoPascua(-3, "Jueves Santo"),
            new FestivoPascua(-2, "Viernes Santo"),
            new FestivoPascua(43, "Ascensión de Jesús"),
            new FestivoPascua(64, "Corpus Christi"),
            new FestivoPascua(71, "Sagrado Corazón de Jesús"));

    private static final int TOTAL_FESTIVOS = FIJOS.size() + TRASLADABLES.size() + DE_PASCUA.size();

    private final Map<Integer, List<Festivo>> cachePorAnio = new ConcurrentHashMap<>();
    private final Map<Integer, Set<LocalDate>> cacheFechas = new ConcurrentHashMap<>();

    /**
     * Devuelve las 18 celebraciones del año, ordenadas por fecha.
     *
     * <p>Puede contener dos celebraciones en la misma fecha; para contar días no laborables use
     * {@link #diasFestivos(int)}.
     */
    public List<Festivo> delAnio(int anio) {
        return cachePorAnio.computeIfAbsent(anio, CalculadoraFestivos::calcular);
    }

    /**
     * Devuelve las fechas festivas únicas del año, ordenadas.
     *
     * <p>Normalmente son 18, pero bajan a 17 los años en que dos celebraciones coinciden.
     */
    public List<LocalDate> diasFestivos(int anio) {
        return delAnio(anio).stream().map(Festivo::fecha).distinct().toList();
    }

    /** Devuelve los festivos que caen dentro del mes indicado. */
    public List<Festivo> delMes(YearMonth mes) {
        return delAnio(mes.getYear()).stream()
                .filter(f -> YearMonth.from(f.fecha()).equals(mes))
                .toList();
    }

    /** Indica si la fecha es festivo en Colombia. */
    public boolean esFestivo(LocalDate fecha) {
        return fechasDelAnio(fecha.getYear()).contains(fecha);
    }

    /** Indica si la fecha es día no laborable: fin de semana o festivo. */
    public boolean esNoLaborable(LocalDate fecha) {
        return fecha.getDayOfWeek() == DayOfWeek.SATURDAY
                || fecha.getDayOfWeek() == DayOfWeek.SUNDAY
                || esFestivo(fecha);
    }

    private Set<LocalDate> fechasDelAnio(int anio) {
        return cacheFechas.computeIfAbsent(anio,
                a -> delAnio(a).stream().map(Festivo::fecha).collect(Collectors.toUnmodifiableSet()));
    }

    private static List<Festivo> calcular(int anio) {
        List<Festivo> festivos = new ArrayList<>(TOTAL_FESTIVOS);

        for (FestivoFijo f : FIJOS) {
            LocalDate fecha = LocalDate.of(anio, f.mes(), f.dia());
            festivos.add(new Festivo(fecha, f.nombre(), TipoFestivo.FIJO, fecha));
        }

        for (FestivoFijo f : TRASLADABLES) {
            LocalDate original = LocalDate.of(anio, f.mes(), f.dia());
            festivos.add(new Festivo(
                    trasladarALunes(original), f.nombre(), TipoFestivo.TRASLADADO, original));
        }

        LocalDate pascua = domingoDeResurreccion(anio);
        for (FestivoPascua f : DE_PASCUA) {
            LocalDate fecha = pascua.plusDays(f.desplazamiento());
            festivos.add(new Festivo(fecha, f.nombre(), TipoFestivo.PASCUA, fecha));
        }

        return festivos.stream()
                .sorted(java.util.Comparator.comparing(Festivo::fecha))
                .toList();
    }

    /** Aplica la Ley Emiliani: si no cae en lunes, se corre al lunes siguiente. */
    private static LocalDate trasladarALunes(LocalDate fecha) {
        return fecha.getDayOfWeek() == DayOfWeek.MONDAY
                ? fecha
                : fecha.with(TemporalAdjusters.next(DayOfWeek.MONDAY));
    }

    /**
     * Calcula el Domingo de Resurrección con el algoritmo de Meeus/Butcher para el calendario
     * gregoriano.
     */
    public static LocalDate domingoDeResurreccion(int anio) {
        int a = anio % 19;
        int b = anio / 100;
        int c = anio % 100;
        int d = b / 4;
        int e = b % 4;
        int f = (b + 8) / 25;
        int g = (b - f + 1) / 3;
        int h = (19 * a + b - d - g + 15) % 30;
        int i = c / 4;
        int k = c % 4;
        int l = (32 + 2 * e + 2 * i - h - k) % 7;
        int m = (a + 11 * h + 22 * l) / 451;

        int mes = (h + l - 7 * m + 114) / 31;
        int dia = ((h + l - 7 * m + 114) % 31) + 1;

        return LocalDate.of(anio, mes, dia);
    }

    private record FestivoFijo(int mes, int dia, String nombre) {}

    private record FestivoPascua(int desplazamiento, String nombre) {}
}
