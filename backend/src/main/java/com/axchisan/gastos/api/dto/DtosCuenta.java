package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.Cuenta;
import com.axchisan.gastos.dominio.TipoCuenta;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Datos de entrada y salida de las cuentas con su saldo real. */
public final class DtosCuenta {

    private DtosCuenta() {
    }

    /**
     * @param saldo         lo que debería haber hoy: el saldo anotado más lo apuntado después
     * @param saldoAnotado  la cifra que se anotó el día {@code saldoAl}
     * @param cambio        lo apuntado después de anotarlo ({@code saldo − saldoAnotado})
     */
    public record CuentaDto(UUID id, String nombre, TipoCuenta tipo, BigDecimal saldo,
                            LocalDate saldoAl, boolean activa, int orden,
                            BigDecimal saldoAnotado, BigDecimal cambio,
                            OffsetDateTime anotadoEn) {

        public static CuentaDto de(Cuenta c) {
            return new CuentaDto(c.getId(), c.getNombre(), c.getTipo(), c.getSaldoEstimado(),
                    c.getSaldoAl(), c.isActiva(), c.getOrden(), c.getSaldo(), c.getCambio(),
                    c.getSaldoAnotadoEn());
        }
    }

    public record CrearCuentaRequest(
            @NotBlank @Size(max = 60) String nombre,
            @NotNull TipoCuenta tipo,
            @PositiveOrZero BigDecimal saldo,
            LocalDate saldoAl) {
    }

    public record ActualizarCuentaRequest(
            @Size(min = 1, max = 60) String nombre,
            TipoCuenta tipo,
            @PositiveOrZero BigDecimal saldo,
            LocalDate saldoAl,
            Boolean activa) {
    }
}
