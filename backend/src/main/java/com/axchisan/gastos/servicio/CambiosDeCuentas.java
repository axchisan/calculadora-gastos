package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.Cuenta;
import com.axchisan.gastos.dominio.TipoCuenta;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Lo que se apuntó después de anotar el saldo de cada cuenta, para que «Mis cuentas» y el total
 * de Inicio no se queden atrás hasta la siguiente vez que se miren los bancos.
 *
 * <p>Sigue exactamente lo que mueve el disponible del mes: compras al contado, gastos pagados,
 * ingresos recibidos, pagos de sueldo, abonos y cobros de deudas, cuotas de crédito y
 * movimientos de ahorro. Las compras en efectivo bajan la cuenta de efectivo; todo lo demás va a
 * la cuenta principal (el primer banco), porque la app no sabe de qué cuenta salió cada cosa. Al
 * anotar el saldo real todo vuelve a cuadrar.
 *
 * <p>«Después» es estrictamente posterior al momento en que se anotó el saldo: lo apuntado en la
 * misma sincronización ya estaba incluido en la cifra del banco. Para lo que solo tiene fecha
 * (pagos de gastos y cuotas) cuenta desde el día siguiente, o el mismo día si se tocó después.
 * El saldo con el que abre cada mes (ingreso de tipo {@code SALDO}) no cuenta: es la misma plata
 * que ya estaba en las cuentas.
 */
@Component
public class CambiosDeCuentas {

    private static final String EFECTIVO = """
            SELECT coalesce(sum(p.monto), 0) FROM purchases p
              JOIN budget_months m ON m.id = p.budget_month_id
             WHERE m.user_id = :u AND p.medio = 'EFECTIVO' AND p.created_at > :ts
            """;

    private static final String RESTO = """
            SELECT
              (SELECT coalesce(sum(i.monto), 0) FROM incomes i
                 JOIN budget_months m ON m.id = i.budget_month_id
                WHERE m.user_id = :u AND i.recibido AND i.tipo <> 'SALDO'
                  AND i.created_at > :ts)
            + (SELECT coalesce(sum(ip.monto_pesos), 0) FROM income_payments ip
                 JOIN income_sources s ON s.id = ip.source_id
                WHERE s.user_id = :u AND ip.created_at > :ts)
            - (SELECT coalesce(sum(p.monto), 0) FROM purchases p
                 JOIN budget_months m ON m.id = p.budget_month_id
                WHERE m.user_id = :u AND p.medio = 'DEBITO' AND p.created_at > :ts)
            - (SELECT coalesce(sum(e.monto_pagado), 0) FROM expenses e
                 JOIN budget_months m ON m.id = e.budget_month_id
                WHERE m.user_id = :u AND e.monto_pagado > 0 AND e.fecha_pago IS NOT NULL
                  AND (e.fecha_pago > :d OR (e.fecha_pago = :d AND e.updated_at > :ts)))
            - (SELECT coalesce(sum(coalesce(q.monto_pagado, q.valor_cuota)), 0)
                 FROM credit_installments q JOIN credits c ON c.id = q.credit_id
                WHERE c.user_id = :u AND q.pagada AND q.fecha_pago > :d)
            + (SELECT coalesce(sum(CASE WHEN d.a_favor THEN a.monto ELSE -a.monto END), 0)
                 FROM debt_payments a JOIN debts d ON d.id = a.debt_id
                WHERE d.user_id = :u AND a.created_at > :ts)
            + (SELECT coalesce(sum(CASE WHEN sm.tipo = 'APORTE' THEN -sm.monto
                                        ELSE sm.monto END), 0)
                 FROM savings_movements sm JOIN savings_goals g ON g.id = sm.savings_goal_id
                WHERE g.user_id = :u AND sm.created_at > :ts)
            """;

    private final EntityManager em;

    public CambiosDeCuentas(EntityManager em) {
        this.em = em;
    }

    /** Pone a cada cuenta su cambio desde que se anotó el saldo. */
    public void calcular(UUID usuarioId, List<Cuenta> cuentas) {
        cuentas.forEach(c -> c.setCambio(BigDecimal.ZERO));
        List<Cuenta> activas = cuentas.stream().filter(Cuenta::isActiva).toList();
        Optional<Cuenta> efectivo = activas.stream()
                .filter(c -> c.getTipo() == TipoCuenta.EFECTIVO)
                .min(Comparator.comparingInt(Cuenta::getOrden));
        Optional<Cuenta> principal = activas.stream()
                .filter(c -> c.getTipo() == TipoCuenta.BANCO)
                .min(Comparator.comparingInt(Cuenta::getOrden))
                .or(() -> activas.stream()
                        .filter(c -> c.getTipo() != TipoCuenta.EFECTIVO)
                        .min(Comparator.comparingInt(Cuenta::getOrden)));
        efectivo.ifPresent(c -> c.setCambio(
                consultar(EFECTIVO, usuarioId, c.getSaldoAnotadoEn(), null).negate()));
        principal.ifPresent(c -> c.setCambio(
                consultar(RESTO, usuarioId, c.getSaldoAnotadoEn(), c.getSaldoAl())));
    }

    private BigDecimal consultar(String sql, UUID usuarioId, OffsetDateTime desde,
                                 LocalDate dia) {
        Query q = em.createNativeQuery(sql)
                .setParameter("u", usuarioId)
                .setParameter("ts", desde);
        if (dia != null) {
            q.setParameter("d", dia);
        }
        Object r = q.getSingleResult();
        return r == null ? BigDecimal.ZERO : new BigDecimal(r.toString());
    }
}
