package com.axchisan.gastos.sueldo;

import com.axchisan.gastos.calendario.CalculadoraFestivos;
import com.axchisan.gastos.dominio.MedioCobro;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("Pagos de un sueldo en dólares")
class CalculadoraSueldoTest {

    private final CalculadoraFestivos festivos = new CalculadoraFestivos();

    private CondicionesCobro contrato(MedioCobro medio, String comision, String fija,
                                      String descuento, String retiro) {
        return new CondicionesCobro(new BigDecimal("600"), LocalDate.of(2026, 10, 23), null,
                medio, 5, 2, new BigDecimal("3301.91"), new BigDecimal(comision),
                new BigDecimal(fija), new BigDecimal(descuento), new BigDecimal(retiro));
    }

    @Test
    @DisplayName("Empezar a mitad de mes pasa esos días al pago del primer mes completo")
    void primerPagoAcumulaLosDiasSueltos() {
        List<PagoProyectado> pagos = CalculadoraSueldo.proyectar(
                contrato(MedioCobro.TRANSFERENCIA, "0", "0", "0", "0"),
                YearMonth.of(2026, 11), 3, festivos::esNoLaborable);

        // En noviembre no hay pago: octubre quedó incompleto y se suma al de diciembre.
        assertThat(pagos.get(0).mesDePago()).isEqualTo(YearMonth.of(2026, 12));
        assertThat(pagos.get(0).desde()).isEqualTo(LocalDate.of(2026, 10, 23));
        assertThat(pagos.get(0).hasta()).isEqualTo(LocalDate.of(2026, 11, 30));
        // 9 de los 31 días de octubre más noviembre completo: 174,19 + 600.
        assertThat(pagos.get(0).montoOriginal()).isEqualByComparingTo("774.19");
        assertThat(pagos.get(0).esProrrateado()).isTrue();

        assertThat(pagos.get(1).montoOriginal()).isEqualByComparingTo("600");
        assertThat(pagos.get(1).esProrrateado()).isFalse();
    }

    @Test
    @DisplayName("Una transferencia directa llega a la TRM, redondeada hacia abajo al peso")
    void transferenciaDirecta() {
        PagoProyectado enero = CalculadoraSueldo.proyectar(
                contrato(MedioCobro.TRANSFERENCIA, "0", "0", "0", "0"),
                YearMonth.of(2027, 1), 1, festivos::esNoLaborable).get(0);

        // 600 × 3.301,91 = 1.981.146
        assertThat(enero.montoPesos()).isEqualByComparingTo("1981146");
    }

    @Test
    @DisplayName("Por PayPal se descuentan la comisión, el cambio y el retiro")
    void porPaypal() {
        PagoProyectado enero = CalculadoraSueldo.proyectar(
                contrato(MedioCobro.PAYPAL, "5.40", "0.30", "3.50", "3500"),
                YearMonth.of(2027, 1), 1, festivos::esNoLaborable).get(0);

        // 600 − 32,40 − 0,30 = 567,30 USD; a 3.301,91 × 96,5 % = 3.186,34 → 1.807.612 − 3.500
        assertThat(enero.comisiones()).isEqualByComparingTo("32.70");
        assertThat(enero.montoPesos()).isEqualByComparingTo("1804112");
    }

    @Test
    @DisplayName("La ventana de pago cuenta días hábiles y salta festivos")
    void ventanaDePago() {
        PagoProyectado diciembre = CalculadoraSueldo.proyectar(
                contrato(MedioCobro.TRANSFERENCIA, "0", "0", "0", "0"),
                YearMonth.of(2026, 12), 1, festivos::esNoLaborable).get(0);

        // Diciembre de 2026 empieza en martes; el 8 es festivo (Inmaculada Concepción).
        assertThat(diciembre.primerDiaPosible()).isEqualTo(LocalDate.of(2026, 12, 1));
        assertThat(diciembre.fechaLimite()).isEqualTo(LocalDate.of(2026, 12, 7));
        assertThat(diciembre.fechaTardia()).isEqualTo(LocalDate.of(2026, 12, 10));
        assertThat(diciembre.mesPresupuestal()).isEqualTo(YearMonth.of(2026, 12));
    }

    @Test
    @DisplayName("Noviembre de 2026 arranca con el festivo del lunes 2")
    void noviembreConFestivo() {
        assertThat(CalculadoraSueldo.diaHabil(YearMonth.of(2026, 11), 1, festivos::esNoLaborable))
                .isEqualTo(LocalDate.of(2026, 11, 3));
        assertThat(CalculadoraSueldo.diaHabil(YearMonth.of(2026, 11), 5, festivos::esNoLaborable))
                .isEqualTo(LocalDate.of(2026, 11, 9));
    }

    @Test
    @DisplayName("Con fecha de fin, el último pago cubre hasta ese día y no hay más")
    void conFechaDeFin() {
        CondicionesCobro c = new CondicionesCobro(new BigDecimal("600"),
                LocalDate.of(2026, 10, 23), LocalDate.of(2026, 12, 22), MedioCobro.TRANSFERENCIA,
                5, 0, new BigDecimal("4000"), BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                BigDecimal.ZERO);

        List<PagoProyectado> pagos = CalculadoraSueldo.proyectar(c, YearMonth.of(2026, 11), 6,
                festivos::esNoLaborable);

        assertThat(pagos).hasSize(2);
        assertThat(pagos.get(1).hasta()).isEqualTo(LocalDate.of(2026, 12, 22));
        // 22 de 31 días de diciembre.
        assertThat(pagos.get(1).montoOriginal()).isEqualByComparingTo("425.81");
    }
}
