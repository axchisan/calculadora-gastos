package com.axchisan.gastos.dominio;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.time.LocalDate;
import java.time.YearMonth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * El ciclo de facturación de una tarjeta de crédito.
 *
 * <p>Las fechas de este archivo son las reales de la tarjeta que motivó el cálculo: corte el 15,
 * pago el 4 del mes siguiente.
 */
@DisplayName("Ciclo de facturación")
class CicloTarjetaTest {

    private static final CicloTarjeta NU = new CicloTarjeta(15, 4);

    @ParameterizedTest(name = "una compra del {0} se paga en {1}")
    @CsvSource({
            // Antes del corte: entra al corte de este mes y se paga el siguiente.
            "2026-08-01, 2026-09",
            "2026-08-14, 2026-09",
            // El propio día del corte todavía entra.
            "2026-08-15, 2026-09",
            // Un día después ya no alcanza: espera al corte siguiente y se paga un mes más tarde.
            "2026-08-16, 2026-10",
            "2026-08-31, 2026-10",
    })
    void el_corte_decide_en_que_mes_se_paga(LocalDate compra, YearMonth pago) {
        assertThat(NU.periodoDePago(compra)).isEqualTo(pago);
    }

    /**
     * Es el detalle que hace que una tarjeta se descuadre al llevarla de memoria: dos días de
     * diferencia en la compra desplazan el pago un mes entero.
     */
    @Test
    void dos_dias_de_diferencia_cambian_el_mes_de_pago() {
        assertThat(NU.vencimientoDe(LocalDate.of(2026, 8, 14)))
                .isEqualTo(LocalDate.of(2026, 9, 4));
        assertThat(NU.vencimientoDe(LocalDate.of(2026, 8, 16)))
                .isEqualTo(LocalDate.of(2026, 10, 4));
    }

    @Test
    void el_cambio_de_anio_no_lo_despista() {
        // Diciembre pasado el corte salta a enero, y de ahí al pago de febrero.
        assertThat(NU.periodoDePago(LocalDate.of(2026, 12, 20)))
                .isEqualTo(YearMonth.of(2027, 2));
        assertThat(NU.vencimientoDe(LocalDate.of(2026, 12, 20)))
                .isEqualTo(LocalDate.of(2027, 2, 4));
    }

    @Test
    void febrero_no_es_un_caso_especial() {
        // Al limitar corte y pago al día 28, el día siempre existe, también en años no bisiestos.
        assertThat(NU.vencimientoDe(LocalDate.of(2027, 1, 20)))
                .isEqualTo(LocalDate.of(2027, 3, 4));
        assertThat(new CicloTarjeta(28, 28).vencimientoDe(LocalDate.of(2027, 12, 29)))
                .isEqualTo(LocalDate.of(2028, 2, 28));
    }

    @Test
    void comprar_justo_despues_del_corte_estira_el_plazo() {
        // Es la razón práctica de conocer el corte: casi dos meses de financiación gratis.
        long justoDespues = NU.diasHastaElPago(LocalDate.of(2026, 8, 16));
        long justoAntes = NU.diasHastaElPago(LocalDate.of(2026, 8, 15));

        assertThat(justoDespues).isEqualTo(49);
        assertThat(justoAntes).isEqualTo(20);
    }

    @Test
    void rechaza_dias_que_no_existen_en_todos_los_meses() {
        assertThatThrownBy(() -> new CicloTarjeta(31, 4))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("entre 1 y 28");
        assertThatThrownBy(() -> new CicloTarjeta(15, 0))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
