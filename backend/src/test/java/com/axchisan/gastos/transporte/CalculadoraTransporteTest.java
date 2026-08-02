package com.axchisan.gastos.transporte;

import com.axchisan.gastos.calendario.CalculadoraFestivos;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Los valores esperados corresponden a la configuración real de uso: pasaje de $3.550 en Bogotá,
 * jornada de lunes a viernes y karate los martes y jueves.
 */
@DisplayName("Motor de cálculo de transporte")
class CalculadoraTransporteTest {

    private static final BigDecimal PASAJE = new BigDecimal("3550");
    private static final YearMonth AGOSTO_2026 = YearMonth.of(2026, 8);

    private final CalculadoraTransporte calculadora =
            new CalculadoraTransporte(new CalculadoraFestivos());
    private final ConfiguracionTransporte config = ConfiguracionTransporte.porDefecto(PASAJE);

    @Nested
    @DisplayName("Pasajes de un día")
    class PasajesPorDia {

        @Test
        void unDiaDeOficinaSinKarateCuestaDosPasajes() {
            // Miércoles 5 de agosto de 2026.
            assertThat(diaDe(LocalDate.of(2026, 8, 5)).pasajes()).isEqualTo(2);
        }

        @Test
        void unDiaDeOficinaConKarateCuestaTresPasajes() {
            // Martes 4 de agosto: casa → oficina → karate → casa.
            DiaTransporte martes = diaDe(LocalDate.of(2026, 8, 4));
            assertThat(martes.hayKarate()).isTrue();
            assertThat(martes.pasajes()).isEqualTo(3);
        }

        @Test
        void unDiaRemotoSinKarateNoCuesta() {
            DiaTransporte remoto = calcularUno(
                    diaManual(LocalDate.of(2026, 8, 5), TipoDia.REMOTO, false));
            assertThat(remoto.pasajes()).isZero();
        }

        @Test
        void unDiaRemotoConKarateCuestaDosPasajes() {
            // Se trabaja desde casa pero igual hay que ir al karate: casa → karate → casa.
            DiaTransporte remoto = calcularUno(
                    diaManual(LocalDate.of(2026, 8, 4), TipoDia.REMOTO, true));
            assertThat(remoto.pasajes()).isEqualTo(2);
        }

        @Test
        void unFestivoEnDiaDeKarateCuestaDosPasajes() {
            // Martes 8 de diciembre de 2026, Inmaculada Concepción: no se trabaja, pero hay clase.
            DiaTransporte festivo = diaDe(YearMonth.of(2026, 12), LocalDate.of(2026, 12, 8));
            assertThat(festivo.tipo()).isEqualTo(TipoDia.FESTIVO);
            assertThat(festivo.hayKarate()).isTrue();
            assertThat(festivo.pasajes()).isEqualTo(2);
        }

        @Test
        void unFestivoSinKarateNoCuesta() {
            // Viernes 7 de agosto de 2026, Batalla de Boyacá.
            assertThat(diaDe(LocalDate.of(2026, 8, 7)).pasajes()).isZero();
        }

        @Test
        void unFinDeSemanaNoCuesta() {
            assertThat(diaDe(LocalDate.of(2026, 8, 1)).pasajes()).isZero();
        }

        @Test
        void enVacacionesNoSeGastaNiSiquieraEnKarate() {
            DiaTransporte vacaciones = calcularUno(
                    diaManual(LocalDate.of(2026, 8, 4), TipoDia.VACACIONES, true));
            assertThat(vacaciones.pasajes()).isZero();
        }
    }

    @Nested
    @DisplayName("Agosto de 2026")
    class AgostoDeDosMilVeintiseis {

        /**
         * Agosto de 2026 tiene 21 días de lunes a viernes, menos dos festivos (viernes 7,
         * Batalla de Boyacá, y lunes 17, Asunción trasladada del 15) = 19 días hábiles.
         * De ellos, 8 son martes o jueves con karate.
         */
        @Test
        void todoPresencialSonCuarentaYSeisPasajes() {
            ResumenTransporte r = calcular(0);

            assertThat(r.diasOficina()).isEqualTo(19);
            assertThat(r.diasFestivos()).isEqualTo(2);
            assertThat(r.diasKarate()).isEqualTo(8);
            // 19 días × 2 pasajes + 8 días de karate × 1 pasaje extra = 46
            assertThat(r.totalPasajes()).isEqualTo(46);
            assertThat(r.costoTotal()).isEqualByComparingTo("163300");
        }

        /**
         * Con un día remoto por semana se propone el viernes. Agosto tiene cuatro viernes, pero
         * el 7 es festivo, así que quedan tres días de trabajo desde casa.
         */
        @Test
        void conUnDiaRemotoPorSemanaSonCuarentaPasajes() {
            ResumenTransporte r = calcular(1);

            assertThat(r.diasOficina()).isEqualTo(16);
            assertThat(r.diasRemotos()).isEqualTo(3);
            // 16 días × 2 + 8 de karate × 1 = 40
            assertThat(r.totalPasajes()).isEqualTo(40);
            assertThat(r.costoTotal()).isEqualByComparingTo("142000");
        }

        /** Con dos días remotos se añade el lunes: cuatro lunes hábiles (el 17 es festivo). */
        @Test
        void conDosDiasRemotosPorSemanaSonTreintaYDosPasajes() {
            ResumenTransporte r = calcular(2);

            assertThat(r.diasOficina()).isEqualTo(12);
            assertThat(r.diasRemotos()).isEqualTo(7);
            // 12 días × 2 + 8 de karate × 1 = 32
            assertThat(r.totalPasajes()).isEqualTo(32);
            assertThat(r.costoTotal()).isEqualByComparingTo("113600");
        }

        @Test
        void elMesTieneTreintaYUnDias() {
            assertThat(calcular(1).dias()).hasSize(31);
        }
    }

    @Nested
    @DisplayName("Escenarios")
    class Escenarios {

        @Test
        void masDiasRemotosNuncaCuestaMas() {
            CalculadoraTransporte.Escenarios e = calculadora.escenarios(AGOSTO_2026, config, 1);

            assertThat(e.optimista().costoTotal())
                    .isLessThanOrEqualTo(e.esperado().costoTotal());
            assertThat(e.esperado().costoTotal())
                    .isLessThanOrEqualTo(e.pesimista().costoTotal());
        }

        @Test
        void elRangoEsLaDiferenciaEntrePeorYMejorCaso() {
            CalculadoraTransporte.Escenarios e = calculadora.escenarios(AGOSTO_2026, config, 1);

            // Pesimista 163.300 (todo presencial) − optimista 113.600 (dos días remotos)
            assertThat(e.rango()).isEqualByComparingTo("49700");
        }
    }

    @Nested
    @DisplayName("Ajustes manuales")
    class AjustesManuales {

        @Test
        void unValorFijadoAManoSobreviveAlRecalculo() {
            List<DiaTransporte> dias = calculadora.generarPropuesta(AGOSTO_2026, config, 1);
            List<DiaTransporte> ajustados = dias.stream()
                    .map(d -> d.fecha().equals(LocalDate.of(2026, 8, 5))
                            ? d.conPasajesManuales(7)
                            : d)
                    .toList();

            ResumenTransporte r = calculadora.calcular(AGOSTO_2026, config, ajustados);

            assertThat(buscar(r, LocalDate.of(2026, 8, 5)).pasajes()).isEqualTo(7);
            // El miércoles 5 costaba 2 pasajes; ahora cuesta 7, cinco más que los 40 originales.
            assertThat(r.totalPasajes()).isEqualTo(45);
        }

        @Test
        void cambiarElTipoDeDiaDescartaElValorManual() {
            DiaTransporte manual = diaManual(LocalDate.of(2026, 8, 5), TipoDia.OFICINA, false)
                    .conPasajesManuales(9);
            assertThat(manual.overrideManual()).isTrue();

            assertThat(manual.conTipo(TipoDia.REMOTO).overrideManual()).isFalse();
        }
    }

    @Nested
    @DisplayName("Seguimiento del gasto real")
    class SeguimientoReal {

        @Test
        void separaLoConfirmadoDeLoPendiente() {
            List<DiaTransporte> dias = calculadora.generarPropuesta(AGOSTO_2026, config, 1);
            // Se confirman los días hasta el 10 de agosto.
            List<DiaTransporte> conConfirmados = dias.stream()
                    .map(d -> d.fecha().isBefore(LocalDate.of(2026, 8, 11))
                            ? new DiaTransporte(d.fecha(), d.tipo(), d.hayKarate(), d.pasajes(),
                                    d.overrideManual(), true, d.nombreFestivo())
                            : d)
                    .toList();

            ResumenTransporte r = calculadora.calcular(AGOSTO_2026, config, conConfirmados);

            assertThat(r.pasajesGastados()).isPositive();
            assertThat(r.pasajesGastados()).isLessThan(r.totalPasajes());
            assertThat(r.costoConfirmado().add(r.costoPendiente()))
                    .isEqualByComparingTo(r.costoTotal());
        }
    }

    // --- utilidades ---

    private ResumenTransporte calcular(int diasRemotosPorSemana) {
        return calculadora.calcular(AGOSTO_2026, config,
                calculadora.generarPropuesta(AGOSTO_2026, config, diasRemotosPorSemana));
    }

    private DiaTransporte diaDe(LocalDate fecha) {
        return diaDe(AGOSTO_2026, fecha);
    }

    private DiaTransporte diaDe(YearMonth mes, LocalDate fecha) {
        return calculadora.generarPropuesta(mes, config, 0).stream()
                .filter(d -> d.fecha().equals(fecha))
                .findFirst()
                .orElseThrow();
    }

    private DiaTransporte diaManual(LocalDate fecha, TipoDia tipo, boolean karate) {
        return new DiaTransporte(fecha, tipo, karate, 0, false, false, null);
    }

    private DiaTransporte calcularUno(DiaTransporte dia) {
        return calculadora
                .calcular(YearMonth.from(dia.fecha()), config, List.of(dia))
                .dias()
                .getFirst();
    }

    private DiaTransporte buscar(ResumenTransporte resumen, LocalDate fecha) {
        return resumen.dias().stream()
                .filter(d -> d.fecha().equals(fecha))
                .findFirst()
                .orElseThrow();
    }
}
