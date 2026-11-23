package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.Credito;
import com.axchisan.gastos.dominio.CuotaCredito;
import com.axchisan.gastos.dominio.Deuda;
import com.axchisan.gastos.repositorio.CreditoRepository;
import com.axchisan.gastos.repositorio.CuotaCreditoRepository;
import com.axchisan.gastos.repositorio.DeudaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * Todo lo que se debe, sumado, y cómo baja mes a mes si se pagan solo las cuotas.
 *
 * <p>Antes, «Debes en total» solo sumaba las deudas informales: un crédito de varios millones no
 * aparecía en la cifra. Aquí se juntan créditos (con su cuadro del banco) y deudas (tarjetas,
 * préstamos, familia), y se proyecta cuándo queda libre cada una.
 */
@Service
public class ServicioPanoramaDeudas {

    /** La proyección no se alarga más allá: cinco años bastan para ver la tendencia. */
    private static final int MESES_MAXIMOS = 60;

    private final DeudaRepository deudas;
    private final CreditoRepository creditos;
    private final CuotaCreditoRepository cuotas;

    public ServicioPanoramaDeudas(DeudaRepository deudas, CreditoRepository creditos,
                                  CuotaCreditoRepository cuotas) {
        this.deudas = deudas;
        this.creditos = creditos;
        this.cuotas = cuotas;
    }

    public enum Origen { CREDITO, DEUDA }

    /**
     * Una deuda viva.
     *
     * @param progreso      qué parte se lleva pagada, de 0 a 1
     * @param terminaEn     mes del último pago si se pagan solo las cuotas; null si no tiene plan
     * @param proximoPago   cuándo y cuánto toca pagar; null si no hay fecha ni cuota
     * @param cuotas        «cuota 4 de 18» en los créditos
     */
    public record Parte(Origen origen, UUID id, String nombre, String tipo, BigDecimal saldo,
                        BigDecimal progreso, YearMonth terminaEn, LocalDate proximoPago,
                        BigDecimal proximoMonto, String cuotas, boolean sinPlan) {
    }

    /** Lo que se deberá al empezar un mes. El primer punto es hoy. */
    public record Punto(YearMonth mes, BigDecimal total) {
    }

    /** Deudas ya saldadas, para enseñarlas plegadas. */
    public record Saldada(Origen origen, UUID id, String nombre) {
    }

    /**
     * @param terminaTodoEn mes en que se termina de pagar todo; null si alguna deuda no tiene plan
     */
    public record Panorama(BigDecimal total, List<Parte> partes, List<Punto> proyeccion,
                           YearMonth terminaTodoEn, List<Saldada> saldadas) {
    }

    @Transactional(readOnly = true)
    public Panorama de(UUID usuarioId, LocalDate hoy) {
        YearMonth actual = YearMonth.from(hoy);
        List<Plan> planes = new ArrayList<>();
        List<Saldada> saldadas = new ArrayList<>();

        for (Credito credito : creditos.listarDelUsuario(usuarioId)) {
            List<CuotaCredito> plan = cuotas.listarDelCredito(credito.getId());
            boolean vivo = credito.isActivo() && plan.stream().anyMatch(q -> !q.isPagada());
            if (vivo) {
                planes.add(planDeCredito(credito, plan, actual));
            } else {
                saldadas.add(new Saldada(Origen.CREDITO, credito.getId(), credito.getEntidad()));
            }
        }
        for (Deuda deuda : deudas.listarDelUsuario(usuarioId)) {
            if (deuda.isActiva() && deuda.getSaldo().signum() > 0) {
                planes.add(planDeDeuda(deuda, actual));
            } else {
                saldadas.add(new Saldada(Origen.DEUDA, deuda.getId(), deuda.getAcreedor()));
            }
        }

        // La proyección: lo que se debe al empezar cada mes, desde hoy hasta que todo queda en
        // cero (o hasta el tope, si alguna deuda no tiene forma de terminar).
        List<Punto> proyeccion = new ArrayList<>();
        BigDecimal total = planes.stream().map(p -> p.saldoAlEmpezar(0))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        proyeccion.add(new Punto(actual, total));
        for (int i = 1; i <= MESES_MAXIMOS; i++) {
            final int k = i;
            BigDecimal enMes = planes.stream().map(p -> p.saldoAlEmpezar(k))
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            proyeccion.add(new Punto(actual.plusMonths(i), enMes));
            if (enMes.signum() == 0) {
                break;
            }
        }

        boolean todasConPlan = planes.stream().noneMatch(p -> p.parte.sinPlan());
        YearMonth terminaTodo = todasConPlan
                ? planes.stream().map(p -> p.parte.terminaEn())
                        .max(Comparator.naturalOrder()).orElse(null)
                : null;

        List<Parte> partes = planes.stream().map(p -> p.parte)
                .sorted(Comparator.comparing(Parte::saldo).reversed())
                .toList();
        return new Panorama(total, partes, proyeccion, terminaTodo, saldadas);
    }

    // --- planes ---

    /** Una deuda con su forma de bajar en el tiempo. */
    private abstract static class Plan {
        final Parte parte;

        Plan(Parte parte) {
            this.parte = parte;
        }

        /** Lo que se deberá al empezar el mes número {@code k} contado desde el actual (0 = hoy). */
        abstract BigDecimal saldoAlEmpezar(int k);
    }

    /**
     * Un crédito baja según su cuadro: al empezar un mes se debe el capital que declara la
     * primera cuota pendiente que vence en ese mes o después.
     */
    private Plan planDeCredito(Credito credito, List<CuotaCredito> plan, YearMonth actual) {
        List<CuotaCredito> pendientes = plan.stream().filter(q -> !q.isPagada()).toList();
        CuotaCredito proxima = pendientes.getFirst();
        CuotaCredito ultima = pendientes.getLast();
        BigDecimal saldo = proxima.getSaldoCapital();
        BigDecimal original = credito.getMontoOriginal();
        long pagadas = plan.size() - pendientes.size();

        Parte parte = new Parte(Origen.CREDITO, credito.getId(), credito.getEntidad(),
                "CREDITO", saldo, proporcion(original.subtract(saldo), original),
                YearMonth.from(ultima.getFecha()), proxima.getFecha(), proxima.getValorCuota(),
                "Cuota " + (pagadas + 1) + " de " + plan.size(), false);

        return new Plan(parte) {
            @Override
            BigDecimal saldoAlEmpezar(int k) {
                if (k == 0) {
                    return saldo;
                }
                LocalDate inicio = actual.plusMonths(k).atDay(1);
                return pendientes.stream()
                        .filter(q -> !q.getFecha().isBefore(inicio))
                        .findFirst()
                        .map(CuotaCredito::getSaldoCapital)
                        .orElse(BigDecimal.ZERO);
            }
        };
    }

    /**
     * Una deuda baja con su cuota mensual (y su interés, si lo tiene), empezando el mes de su
     * fecha límite o el siguiente. Con fecha y sin cuota es un pago único; sin ninguna de las dos
     * no hay forma de saber cuándo termina y se queda igual.
     */
    private Plan planDeDeuda(Deuda deuda, YearMonth actual) {
        BigDecimal saldo = deuda.getSaldo();
        BigDecimal cuota = deuda.getCuotaSugerida();
        BigDecimal tasa = deuda.getTasaInteresMensual() == null
                ? BigDecimal.ZERO
                : deuda.getTasaInteresMensual().divide(BigDecimal.valueOf(100), 8,
                        RoundingMode.HALF_UP);
        LocalDate limite = deuda.getFechaLimite();
        YearMonth primerPago = limite != null && !YearMonth.from(limite).isBefore(actual)
                ? YearMonth.from(limite)
                : actual.plusMonths(1);
        boolean conCuota = cuota != null && cuota.signum() > 0;
        boolean pagoUnico = !conCuota && limite != null;
        boolean sinPlan = !conCuota && !pagoUnico;

        // Saldos al empezar cada mes, calculados una vez.
        List<BigDecimal> saldos = new ArrayList<>();
        saldos.add(saldo);
        BigDecimal restante = saldo;
        YearMonth termina = sinPlan ? null : primerPago;
        for (int k = 1; k <= MESES_MAXIMOS + 1; k++) {
            YearMonth mesAnterior = actual.plusMonths(k - 1);
            if (!sinPlan && restante.signum() > 0 && !mesAnterior.isBefore(primerPago)) {
                if (pagoUnico) {
                    restante = BigDecimal.ZERO;
                } else {
                    BigDecimal conInteres = restante.add(restante.multiply(tasa))
                            .setScale(2, RoundingMode.HALF_UP);
                    restante = conInteres.subtract(cuota).max(BigDecimal.ZERO);
                }
                if (restante.signum() == 0) {
                    termina = mesAnterior;
                }
            }
            saldos.add(restante);
        }
        if (!sinPlan && restante.signum() > 0) {
            // Con la cuota no alcanza ni para el interés: no termina dentro del horizonte.
            termina = null;
        }

        BigDecimal original = deuda.getMontoOriginal();
        Parte parte = new Parte(Origen.DEUDA, deuda.getId(), deuda.getAcreedor(),
                deuda.getTipo().name(), saldo, proporcion(original.subtract(saldo), original),
                termina, sinPlan ? null : primerPago.atDay(limite != null
                        && YearMonth.from(limite).equals(primerPago)
                        ? limite.getDayOfMonth() : 1),
                sinPlan ? null : (pagoUnico ? saldo : cuota.min(saldo)), null,
                sinPlan || termina == null);

        return new Plan(parte) {
            @Override
            BigDecimal saldoAlEmpezar(int k) {
                return saldos.get(Math.min(k, saldos.size() - 1));
            }
        };
    }

    private static BigDecimal proporcion(BigDecimal parte, BigDecimal total) {
        if (total.signum() <= 0) {
            return BigDecimal.ZERO;
        }
        return parte.max(BigDecimal.ZERO).divide(total, 4, RoundingMode.HALF_UP)
                .min(BigDecimal.ONE);
    }
}
