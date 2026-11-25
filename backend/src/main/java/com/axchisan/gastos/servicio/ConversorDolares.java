package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.Gasto;
import com.axchisan.gastos.dominio.PlantillaGasto;
import com.axchisan.gastos.repositorio.FuenteIngresoRepository;
import com.axchisan.gastos.repositorio.GastoRepository;
import com.axchisan.gastos.repositorio.PlantillaGastoRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Comparator;
import java.util.Optional;
import java.util.UUID;

/**
 * Pasa a pesos los gastos fijos que se cobran en dólares, con la misma TRM que el sueldo.
 *
 * <p>La TRM sale de la fuente de ingreso en dólares del usuario, que la pone al día cada día:
 * así el gasto y el sueldo usan exactamente la misma cifra y no hace falta otra consulta.
 */
@Component
public class ConversorDolares {

    private final FuenteIngresoRepository fuentes;
    private final GastoRepository gastos;
    private final PlantillaGastoRepository plantillas;

    public ConversorDolares(FuenteIngresoRepository fuentes, GastoRepository gastos,
                            PlantillaGastoRepository plantillas) {
        this.fuentes = fuentes;
        this.gastos = gastos;
        this.plantillas = plantillas;
    }

    /** La TRM de hoy, si el usuario tiene una fuente de ingreso en dólares. */
    @Transactional(readOnly = true)
    public Optional<BigDecimal> trm(UUID usuarioId) {
        return fuentes.listarDelUsuario(usuarioId).stream()
                .filter(FuenteIngreso::isActivo)
                .filter(f -> "USD".equalsIgnoreCase(f.getMoneda()))
                .filter(f -> f.getTrmReferencia() != null && f.getTrmReferencia().signum() > 0)
                .max(Comparator.comparing(FuenteIngreso::getTrmFecha,
                        Comparator.nullsFirst(Comparator.naturalOrder())))
                .map(FuenteIngreso::getTrmReferencia);
    }

    public static BigDecimal pesos(BigDecimal usd, BigDecimal trm) {
        return usd.multiply(trm).setScale(0, RoundingMode.HALF_UP).setScale(2);
    }

    /**
     * Recalcula los gastos en dólares pendientes de los meses abiertos y el monto de las
     * plantillas en dólares (que es el que usa el plan para los meses que aún no existen).
     */
    @Transactional
    public void recalcular(UUID usuarioId) {
        trm(usuarioId).ifPresent(trm -> {
            for (Gasto g : gastos.pendientesEnDolares(usuarioId)) {
                g.convertirConTrm(trm);
            }
            for (PlantillaGasto p : plantillas.listarDelUsuario(usuarioId)) {
                if (p.getMontoUsd() != null) {
                    p.setMontoDefault(pesos(p.getMontoUsd(), trm));
                }
            }
        });
    }
}
