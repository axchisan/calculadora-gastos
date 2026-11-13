package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.Cuenta;
import com.axchisan.gastos.dominio.TipoCuenta;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/** Datos de entrada y salida de las cuentas con su saldo real. */
public final class DtosCuenta {

    private DtosCuenta() {
    }

    public record CuentaDto(UUID id, String nombre, TipoCuenta tipo, BigDecimal saldo,
                            LocalDate saldoAl, boolean activa, int orden) {

        public static CuentaDto de(Cuenta c) {
            return new CuentaDto(c.getId(), c.getNombre(), c.getTipo(), c.getSaldo(),
                    c.getSaldoAl(), c.isActiva(), c.getOrden());
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
