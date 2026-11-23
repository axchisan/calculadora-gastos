package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.deteccion.ClaseMovimiento;
import com.axchisan.gastos.dominio.MovimientoDetectado;
import com.axchisan.gastos.dominio.ReglaDeteccion;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Datos de entrada y salida de la bandeja de movimientos detectados. */
public final class DtosDetectados {

    private DtosDetectados() {
    }

    /**
     * @param monto       con signo: positivo si entra, negativo si sale
     * @param motivo      por qué se resolvió solo: «Ya llegó por sms», «Ya está: Mercado»…
     */
    public record DetectadoDto(UUID id, MovimientoDetectado.Origen origen, String banco,
                               ClaseMovimiento clase, BigDecimal monto, LocalDate fecha,
                               LocalTime hora, String cuenta, String contraparte,
                               String referencia, MovimientoDetectado.Estado estado,
                               String motivo, UUID duplicadoDe, String coincideTipo,
                               UUID coincideId, ReglaDeteccion.Destino sugerenciaDestino,
                               String sugerenciaCategoria, String sugerenciaNombre,
                               String texto, OffsetDateTime creado) {

        public static DetectadoDto de(MovimientoDetectado d) {
            return new DetectadoDto(d.getId(), d.getOrigen(), d.getBanco(), d.getClase(),
                    d.montoConSigno(), d.getFecha(), d.getHora(), d.getCuenta(),
                    d.getContraparte(), d.getReferencia(), d.getEstado(), d.getMotivo(),
                    d.getDuplicadoDe(), d.getCoincideTipo(), d.getCoincideId(),
                    d.getSugerenciaDestino(), d.getSugerenciaCategoria(),
                    d.getSugerenciaNombre(), d.getTexto(), d.getCreatedAt());
        }
    }

    public record AvisoRequest(
            @NotNull MovimientoDetectado.Origen origen,
            @NotBlank @Size(max = 4000) String texto) {
    }

    public record AvisoResponse(String resultado, DetectadoDto detectado) {
    }

    /** El PDF va en base64 dentro del JSON: Lambda y CloudFront tratan mal los binarios. */
    public record ExtractoRequest(@NotBlank @Size(max = 8_000_000) String pdf) {
    }

    public record DescartarRequest(@Size(max = 200) String motivo) {
    }

    public record ReglaDto(UUID id, ReglaDeteccion.Campo campo, String valor,
                           ReglaDeteccion.Accion accion, ReglaDeteccion.Destino destino,
                           String categoria, String nombre) {

        public static ReglaDto de(ReglaDeteccion r) {
            return new ReglaDto(r.getId(), r.getCampo(), r.getValor(), r.getAccion(),
                    r.getDestino(), r.getCategoria(), r.getNombre());
        }
    }

    public record CrearReglaRequest(
            @NotNull ReglaDeteccion.Campo campo,
            @NotBlank @Size(max = 120) String valor,
            @NotNull ReglaDeteccion.Accion accion,
            ReglaDeteccion.Destino destino,
            @Size(max = 30) String categoria,
            @Size(max = 120) String nombre) {
    }
}
