package com.axchisan.gastos.credito;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

/**
 * Las cuentas del sistema francés, contrastadas contra un plan de pagos real.
 *
 * <p>Las cifras de este archivo salen del cuadro que imprimió Bancamía el 31 de agosto de 2026
 * para la operación 31639650: 4.371.000 al 76% efectivo anual a 18 cuotas. No son ejemplos
 * inventados, y por eso valen: si el motor no reprodujera ese papel, todo lo que se calcule
 * encima estaría mal sin que nada lo delatara.
 */
@DisplayName("Amortización francesa")
class AmortizacionTest {

    /** Saldo de capital al empezar el cuadro, según la primera fila del plan. */
    private static final BigDecimal SALDO = new BigDecimal("4226306.32");

    private static final double TASA_EA = 76.0;

    @Test
    void la_tasa_mensual_no_es_la_anual_dividida_entre_doce() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);

        // El interés se capitaliza: la mensual es la raíz duodécima, no la doceava parte.
        // 1,76^(1/12) - 1 = 4,823677%, que aplicado al saldo del plan da los 203.863 de interés
        // que imprime el banco.
        assertThat(mensual).isCloseTo(0.04823677, within(0.0000001));

        // Dividir entre doce daría 6,33% y todo el cuadro saldría inflado casi un tercio.
        assertThat(mensual).isLessThan(TASA_EA / 100 / 12);
    }

    /**
     * La comprobación que valida todo lo demás: el interés de la segunda cuota del plan real.
     */
    @Test
    void reproduce_el_interes_de_la_primera_cuota_del_plan() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);
        BigDecimal interes = SALDO.multiply(BigDecimal.valueOf(mensual));

        // El papel del banco dice 203.863,36.
        assertThat(interes.doubleValue()).isCloseTo(203863.36, within(1.0));
    }

    @Test
    void reproduce_la_cuota_del_plan() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);
        // Quedan 17 cuotas por delante desde el saldo inicial del cuadro.
        BigDecimal cuota = Amortizacion.cuota(SALDO, mensual, 17);

        // Capital más interés de la cuota 2 del plan: 166.085,74 + 203.863,36 = 369.949,10.
        // La cuota que cobra el banco añade encima el Mipyme y el seguro.
        assertThat(cuota.doubleValue()).isCloseTo(369949.10, within(50.0));
    }

    @Test
    void la_cuota_y_el_plazo_son_la_misma_cuenta_al_derecho_y_al_reves() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);
        BigDecimal cuota = Amortizacion.cuota(SALDO, mensual, 17);

        assertThat(Amortizacion.cuotasNecesarias(SALDO, mensual, cuota)).isEqualTo(17);
    }

    /**
     * Lo que hace que abonar de más merezca la pena, y la razón de todo este módulo.
     */
    @Test
    void abonar_a_capital_ahorra_mucho_mas_que_lo_abonado() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);

        BigDecimal sinAbonar = Amortizacion.interesTotal(SALDO, mensual, 17);
        BigDecimal abono = new BigDecimal("500000");
        BigDecimal tras = Amortizacion.interesTotal(SALDO.subtract(abono), mensual, 17);

        BigDecimal ahorro = sinAbonar.subtract(tras);

        // Medio millón abonado ahorra más de 240.000 solo en intereses, manteniendo el plazo.
        assertThat(ahorro.doubleValue()).isGreaterThan(240000);
        // Y menos que lo abonado: el ahorro es el interés que ese capital ya no genera.
        assertThat(ahorro).isLessThan(abono);
    }

    @Test
    void mantener_la_cuota_tras_abonar_acorta_el_plazo() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);
        BigDecimal cuota = Amortizacion.cuota(SALDO, mensual, 17);

        BigDecimal trasElAbono = SALDO.subtract(new BigDecimal("500000"));
        int cuotasQueQuedan = Amortizacion.cuotasNecesarias(trasElAbono, mensual, cuota);

        assertThat(cuotasQueQuedan).isLessThan(17);
    }

    @Test
    void el_interes_total_del_plan_cuadra_con_el_papel() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);
        BigDecimal interes = Amortizacion.interesTotal(SALDO, mensual, 17);

        // El plan suma 2.062.828,55 de interés en las diecisiete cuotas que quedan.
        assertThat(interes.doubleValue()).isCloseTo(2062828.55, within(2000.0));
    }

    @Test
    void una_cuota_que_no_cubre_ni_el_interes_se_rechaza() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);

        // Pagando menos que el interés del mes la deuda crecería para siempre.
        assertThatThrownBy(
                () -> Amortizacion.cuotasNecesarias(SALDO, mensual, new BigDecimal("100000")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("crecería");
    }

    @Test
    void un_credito_sin_intereses_se_reparte_a_partes_iguales() {
        BigDecimal cuota = Amortizacion.cuota(new BigDecimal("1200000"), 0, 12);

        assertThat(cuota).isEqualByComparingTo("100000");
        assertThat(Amortizacion.interesTotal(new BigDecimal("1200000"), 0, 12))
                .isEqualByComparingTo("0");
    }

    @Test
    void un_saldo_saldado_no_pide_nada_mas() {
        double mensual = Amortizacion.mensualDesdeEfectivaAnual(TASA_EA);

        assertThat(Amortizacion.cuota(BigDecimal.ZERO, mensual, 12)).isEqualByComparingTo("0");
        assertThat(Amortizacion.cuotasNecesarias(BigDecimal.ZERO, mensual, new BigDecimal("1")))
                .isZero();
    }
}
