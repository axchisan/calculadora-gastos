package com.axchisan.gastos.calendario;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("Calculadora de festivos colombianos")
class CalculadoraFestivosTest {

    private final CalculadoraFestivos calculadora = new CalculadoraFestivos();

    @Nested
    @DisplayName("Domingo de Resurrección")
    class Pascua {

        @ParameterizedTest(name = "{0} → {1}")
        @CsvSource({
                "2020, 2020-04-12",
                "2021, 2021-04-04",
                "2022, 2022-04-17",
                "2023, 2023-04-09",
                "2024, 2024-03-31",
                "2025, 2025-04-20",
                "2026, 2026-04-05",
                "2027, 2027-03-28",
                "2028, 2028-04-16",
                "2030, 2030-04-21"
        })
        void calculaLaFechaCorrecta(int anio, LocalDate esperada) {
            assertThat(CalculadoraFestivos.domingoDeResurreccion(anio)).isEqualTo(esperada);
        }

        @ParameterizedTest
        @ValueSource(ints = {2015, 2020, 2026, 2030, 2040, 2050})
        void siempreCaeEnDomingo(int anio) {
            assertThat(CalculadoraFestivos.domingoDeResurreccion(anio).getDayOfWeek())
                    .isEqualTo(DayOfWeek.SUNDAY);
        }
    }

    @Nested
    @DisplayName("Composición del año")
    class ComposicionDelAnio {

        @ParameterizedTest
        @ValueSource(ints = {2020, 2024, 2025, 2026, 2027, 2030, 2035})
        void tieneDieciochoCelebraciones(int anio) {
            assertThat(calculadora.delAnio(anio)).hasSize(18);
        }

        @ParameterizedTest
        @ValueSource(ints = {2020, 2024, 2026, 2027, 2035})
        void enAniosSinCoincidenciaHayDieciochoDias(int anio) {
            assertThat(calculadora.diasFestivos(anio)).hasSize(18);
        }

        @Test
        void devuelveLosFestivosOrdenadosPorFecha() {
            List<Festivo> festivos = calculadora.delAnio(2026);
            assertThat(festivos).isSortedAccordingTo(
                    java.util.Comparator.comparing(Festivo::fecha));
        }
    }

    @Nested
    @DisplayName("Ley Emiliani")
    class LeyEmiliani {

        @ParameterizedTest(name = "{2} de {0} se celebra el {1}")
        @CsvSource({
                // En 2026 el 6 de enero cae martes, así que Reyes se corre al lunes 12.
                "2026, 2026-01-12, Reyes Magos",
                "2026, 2026-03-23, San José",
                "2026, 2026-08-17, Asunción de la Virgen",
                "2026, 2026-11-02, Todos los Santos",
                "2026, 2026-11-16, Independencia de Cartagena",
                "2027, 2027-01-11, Reyes Magos",
                "2027, 2027-10-18, Día de la Raza"
        })
        void trasladaAlLunesSiguiente(int anio, LocalDate esperada, String nombre) {
            assertThat(buscar(anio, nombre).fecha()).isEqualTo(esperada);
        }

        @Test
        void noTrasladaSiYaCaeEnLunes() {
            // El 12 de octubre de 2026 es lunes: se celebra en su fecha.
            Festivo raza = buscar(2026, "Día de la Raza");
            assertThat(raza.fecha()).isEqualTo(LocalDate.of(2026, 10, 12));
            assertThat(raza.fueTrasladado()).isFalse();
        }

        @ParameterizedTest
        @ValueSource(ints = {2024, 2025, 2026, 2027, 2028, 2030})
        void todosLosTrasladablesCaenEnLunes(int anio) {
            assertThat(calculadora.delAnio(anio))
                    .filteredOn(f -> f.tipo() == TipoFestivo.TRASLADADO)
                    .allSatisfy(f -> assertThat(f.fecha().getDayOfWeek())
                            .isEqualTo(DayOfWeek.MONDAY));
        }

        @Test
        void losFestivosFijosNuncaSeTrasladan() {
            // El 25 de diciembre de 2027 cae sábado y aun así se celebra ese día.
            assertThat(buscar(2027, "Navidad").fecha()).isEqualTo(LocalDate.of(2027, 12, 25));
            assertThat(buscar(2027, "Día del Trabajo").fecha())
                    .isEqualTo(LocalDate.of(2027, 5, 1));
        }
    }

    @Nested
    @DisplayName("Festivos derivados de la Pascua")
    class DerivadosDePascua {

        @ParameterizedTest(name = "{2} de {0} → {1}")
        @CsvSource({
                "2026, 2026-04-02, Jueves Santo",
                "2026, 2026-04-03, Viernes Santo",
                "2026, 2026-05-18, Ascensión de Jesús",
                "2026, 2026-06-08, Corpus Christi",
                "2026, 2026-06-15, Sagrado Corazón de Jesús",
                "2025, 2025-04-17, Jueves Santo",
                "2025, 2025-04-18, Viernes Santo"
        })
        void seCalculanDesdeLaPascua(int anio, LocalDate esperada, String nombre) {
            assertThat(buscar(anio, nombre).fecha()).isEqualTo(esperada);
        }

        @ParameterizedTest
        @ValueSource(ints = {2024, 2025, 2026, 2027, 2030})
        void semanaSantaCaeEnJuevesYViernes(int anio) {
            assertThat(buscar(anio, "Jueves Santo").fecha().getDayOfWeek())
                    .isEqualTo(DayOfWeek.THURSDAY);
            assertThat(buscar(anio, "Viernes Santo").fecha().getDayOfWeek())
                    .isEqualTo(DayOfWeek.FRIDAY);
        }

        @ParameterizedTest
        @ValueSource(ints = {2024, 2025, 2026, 2027, 2030})
        void losDemasFestivosDePascuaCaenEnLunes(int anio) {
            assertThat(buscar(anio, "Ascensión de Jesús").fecha().getDayOfWeek())
                    .isEqualTo(DayOfWeek.MONDAY);
            assertThat(buscar(anio, "Corpus Christi").fecha().getDayOfWeek())
                    .isEqualTo(DayOfWeek.MONDAY);
            assertThat(buscar(anio, "Sagrado Corazón de Jesús").fecha().getDayOfWeek())
                    .isEqualTo(DayOfWeek.MONDAY);
        }
    }

    @Nested
    @DisplayName("Coincidencia de dos festivos en la misma fecha")
    class Coincidencias {

        /**
         * Cuando el 29 de junio cae en domingo, San Pedro y San Pablo se traslada al lunes 30 y
         * coincide con el Sagrado Corazón. Ese año Colombia tiene 17 días festivos, no 18.
         */
        @ParameterizedTest
        @ValueSource(ints = {2019, 2025, 2030, 2038, 2041})
        void esosAniosTienenDiecisieteDiasFestivos(int anio) {
            assertThat(calculadora.delAnio(anio)).hasSize(18);
            assertThat(calculadora.diasFestivos(anio)).hasSize(17);
        }

        @Test
        void enDosMilVeinticincoCoincidenElTreintaDeJunio() {
            LocalDate coincidencia = LocalDate.of(2025, 6, 30);
            assertThat(buscar(2025, "Sagrado Corazón de Jesús").fecha()).isEqualTo(coincidencia);
            assertThat(buscar(2025, "San Pedro y San Pablo").fecha()).isEqualTo(coincidencia);
        }
    }

    @Nested
    @DisplayName("Consultas")
    class Consultas {

        @Test
        void reconoceUnDiaFestivo() {
            assertThat(calculadora.esFestivo(LocalDate.of(2026, 8, 7))).isTrue();
            assertThat(calculadora.esFestivo(LocalDate.of(2026, 8, 17))).isTrue();
        }

        @Test
        void unDiaCorrienteNoEsFestivo() {
            assertThat(calculadora.esFestivo(LocalDate.of(2026, 8, 10))).isFalse();
            // El 15 de agosto es la fecha original de la Asunción, pero se trasladó al 17.
            assertThat(calculadora.esFestivo(LocalDate.of(2026, 8, 15))).isFalse();
        }

        @Test
        void agostoDeDosMilVeintiseisTieneDosFestivos() {
            assertThat(calculadora.delMes(YearMonth.of(2026, 8)))
                    .extracting(Festivo::fecha)
                    .containsExactly(LocalDate.of(2026, 8, 7), LocalDate.of(2026, 8, 17));
        }

        @Test
        void septiembreNuncaTieneFestivos() {
            assertThat(calculadora.delMes(YearMonth.of(2026, 9))).isEmpty();
        }

        @Test
        void losFinesDeSemanaSonNoLaborables() {
            assertThat(calculadora.esNoLaborable(LocalDate.of(2026, 8, 1))).isTrue();  // sábado
            assertThat(calculadora.esNoLaborable(LocalDate.of(2026, 8, 2))).isTrue();  // domingo
            assertThat(calculadora.esNoLaborable(LocalDate.of(2026, 8, 3))).isFalse(); // lunes
        }
    }

    private Festivo buscar(int anio, String nombre) {
        return calculadora.delAnio(anio).stream()
                .filter(f -> f.nombre().equals(nombre))
                .findFirst()
                .orElseThrow(() -> new AssertionError(
                        "No se encontró el festivo '" + nombre + "' en " + anio));
    }
}
