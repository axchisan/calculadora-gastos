package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.AliasTarjeta;
import com.axchisan.gastos.dominio.CategoriaGasto;
import com.axchisan.gastos.dominio.Compra;
import com.axchisan.gastos.dominio.MedioPago;
import com.axchisan.gastos.dominio.OrigenCompra;
import com.axchisan.gastos.dominio.Tarjeta;
import com.axchisan.gastos.dominio.TipoTarjeta;
import com.axchisan.gastos.servicio.ServicioCompras;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Datos de entrada y salida de las compras del día a día y de las tarjetas. */
public final class DtosCompra {

    private DtosCompra() {
    }

    // --- tarjetas ---

    public record TarjetaDto(UUID id, String nombre, TipoTarjeta tipo, Short diaCorte,
                             Short diaPago, String color, boolean activa,
                             List<AliasDto> alias) {

        public static TarjetaDto de(Tarjeta tarjeta) {
            return de(tarjeta, List.of());
        }

        public static TarjetaDto de(Tarjeta tarjeta, List<AliasTarjeta> alias) {
            return new TarjetaDto(tarjeta.getId(), tarjeta.getNombre(), tarjeta.getTipo(),
                    tarjeta.getDiaCorte(), tarjeta.getDiaPago(), tarjeta.getColor(),
                    tarjeta.isActiva(), alias.stream().map(AliasDto::de).toList());
        }
    }

    /**
     * Cómo reconocer la tarjeta en una notificación de pago.
     *
     * @param apodo    el nombre que tiene dentro de Google Wallet
     * @param ultimos4 los cuatro últimos dígitos, que publica el banco
     */
    public record AliasDto(UUID id, String apodo, String ultimos4) {

        public static AliasDto de(AliasTarjeta alias) {
            return new AliasDto(alias.getId(), alias.getAlias(), alias.getUltimos4());
        }
    }

    public record AnadirAliasRequest(
            @Size(max = 60, message = "El apodo no puede pasar de 60 caracteres")
            String apodo,

            @Pattern(regexp = "\\d{4}", message = "Deben ser exactamente cuatro dígitos")
            String ultimos4) {
    }

    public record CrearTarjetaRequest(

            @NotBlank(message = "El nombre es obligatorio")
            @Size(max = 60, message = "El nombre no puede pasar de 60 caracteres")
            String nombre,

            @NotNull(message = "Hay que indicar si es de débito o de crédito")
            TipoTarjeta tipo,

            // Se limitan a 28 para que el día exista en todos los meses, febrero incluido.
            @Min(value = 1, message = "El día de corte debe estar entre 1 y 28")
            @Max(value = 28, message = "El día de corte debe estar entre 1 y 28")
            Integer diaCorte,

            @Min(value = 1, message = "El día de pago debe estar entre 1 y 28")
            @Max(value = 28, message = "El día de pago debe estar entre 1 y 28")
            Integer diaPago,

            String color) {
    }

    public record ActualizarTarjetaRequest(
            @Size(max = 60) String nombre,
            @Min(1) @Max(28) Integer diaCorte,
            @Min(1) @Max(28) Integer diaPago,
            String color,
            Boolean activa) {
    }

    // --- compras ---

    /**
     * Una compra tal y como la ve el cliente.
     *
     * @param periodoPago mes del que sale el dinero, en formato {@code aaaa-mm}; con crédito no
     *                    coincide con el mes de la compra
     * @param vencimiento fecha exacta en que hay que pagarla
     * @param pagado      con efectivo o débito siempre cierto; con crédito, hasta que se salde
     *                    el corte
     */
    public record CompraDto(UUID id, LocalDate fecha, String descripcion,
                            CategoriaGasto categoria, BigDecimal monto, MedioPago medio,
                            UUID tarjetaId, String tarjetaNombre, String periodoPago,
                            LocalDate vencimiento, boolean pagado, OrigenCompra origen,
                            String nota) {

        public static CompraDto de(Compra compra) {
            Tarjeta tarjeta = compra.getTarjeta();
            return new CompraDto(
                    compra.getId(), compra.getFecha(), compra.getDescripcion(),
                    compra.getCategoria(), compra.getMonto(), compra.getMedio(),
                    tarjeta == null ? null : tarjeta.getId(),
                    tarjeta == null ? null : tarjeta.getNombre(),
                    compra.periodoDePago().toString(), compra.vencimiento(),
                    compra.isPagado(), compra.getOrigen(), compra.getNota());
        }
    }

    public record RegistrarCompraRequest(

            @NotBlank(message = "La descripción es obligatoria")
            @Size(max = 120, message = "La descripción no puede pasar de 120 caracteres")
            String descripcion,

            @NotNull(message = "El monto es obligatorio")
            @Positive(message = "El monto debe ser mayor que cero")
            BigDecimal monto,

            @NotNull(message = "La categoría es obligatoria")
            CategoriaGasto categoria,

            // Si no se indica, se toma el día de hoy.
            LocalDate fecha,

            // Si no se indica, se asume efectivo.
            MedioPago medio,

            UUID tarjetaId,

            @Size(max = 200) String nota) {
    }

    public record ActualizarCompraRequest(
            @Size(max = 120) String descripcion,
            @Positive BigDecimal monto,
            CategoriaGasto categoria,
            LocalDate fecha,
            MedioPago medio,
            UUID tarjetaId,
            @Size(max = 200) String nota) {
    }

    /**
     * Resumen de las compras de un mes.
     *
     * @param total      todo lo comprado, se haya pagado ya o quede a deber en la tarjeta
     * @param inmediato  lo que salió del bolsillo en el acto
     * @param aCredito   lo cargado a tarjetas, que se paga más adelante
     * @param porDia     cuánto se gastó cada día, para ver el ritmo del mes
     * @param compras    el detalle, de la más reciente a la más antigua
     */
    public record ComprasDelMesDto(BigDecimal total, BigDecimal inmediato, BigDecimal aCredito,
                                   List<TotalDia> porDia, List<CompraDto> compras) {

        public record TotalDia(LocalDate fecha, BigDecimal total) {
        }
    }

    // --- cortes de tarjeta ---

    /**
     * Lo que hay que pagarle a una tarjeta en un mes.
     *
     * @param periodo     mes en que vence, en formato {@code aaaa-mm}
     * @param vencimiento fecha exacta del pago
     * @param total       lo que sumó el corte
     * @param pendiente   lo que falta por pagar de ese corte
     */
    public record CorteTarjetaDto(UUID tarjetaId, String tarjetaNombre, String periodo,
                                  LocalDate vencimiento, BigDecimal total, BigDecimal pendiente,
                                  boolean saldado, List<CompraDto> compras) {

        public static CorteTarjetaDto de(ServicioCompras.CorteTarjeta corte) {
            return new CorteTarjetaDto(
                    corte.tarjeta().getId(), corte.tarjeta().getNombre(),
                    corte.periodo().toString(), corte.vencimiento(),
                    corte.total(), corte.pendiente(), corte.estaSaldado(),
                    corte.compras().stream().map(CompraDto::de).toList());
        }
    }

    public record SaldarCorteRequest(
            @NotNull(message = "Hay que indicar si el corte queda pagado")
            Boolean pagado) {
    }
}
