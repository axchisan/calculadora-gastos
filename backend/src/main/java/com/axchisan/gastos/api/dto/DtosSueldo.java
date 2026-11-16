package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.MedioCobro;
import com.axchisan.gastos.dominio.PagoRecibido;
import com.axchisan.gastos.servicio.ServicioSueldo;
import com.axchisan.gastos.sueldo.ClienteTrm;
import com.axchisan.gastos.sueldo.PagoProyectado;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Datos de entrada y salida de los ingresos en otra moneda. */
public final class DtosSueldo {

    private DtosSueldo() {
    }

    public record FuenteDto(UUID id, String nombre, String moneda, BigDecimal montoMensual,
                            LocalDate fechaInicio, LocalDate fechaFin, MedioCobro medio,
                            String cuentaDestino, int diasHabilesPago, int diasTolerancia,
                            BigDecimal trm, LocalDate trmFecha, boolean trmAutomatica,
                            BigDecimal comisionPorcentaje, BigDecimal comisionFija,
                            BigDecimal descuentoCambioPorcentaje, BigDecimal costoRetiro,
                            boolean activo, String notas, List<PagoDto> proximosPagos,
                            List<RecibidoDto> recibidos) {

        public static FuenteDto de(FuenteIngreso f, List<PagoProyectado> proyectados,
                                   List<PagoRecibido> recibidos) {
            Map<String, PagoRecibido> porMes = new java.util.HashMap<>();
            recibidos.forEach(r -> porMes.put(r.getMesDePago().toString(), r));
            return new FuenteDto(f.getId(), f.getNombre(), f.getMoneda(), f.getMontoMensual(),
                    f.getFechaInicio(), f.getFechaFin(), f.getMedio(), f.getCuentaDestino(),
                    f.getDiasHabilesPago(), f.getDiasTolerancia(), f.getTrmReferencia(),
                    f.getTrmFecha(), f.isTrmAutomatica(), f.getComisionPorcentaje(),
                    f.getComisionFija(), f.getDescuentoCambioPorcentaje(), f.getCostoRetiro(),
                    f.isActivo(), f.getNotas(),
                    proyectados.stream()
                            .map(p -> PagoDto.de(p, porMes.get(p.mesDePago().toString())))
                            .toList(),
                    recibidos.stream().map(RecibidoDto::de).toList());
        }
    }

    /**
     * Un pago proyectado. Si ya llegó, {@code recibido} trae lo que de verdad entró.
     */
    public record PagoDto(String mesDePago, LocalDate desde, LocalDate hasta, int diasCubiertos,
                          boolean prorrateado, BigDecimal montoOriginal, BigDecimal comisiones,
                          BigDecimal montoPesos, LocalDate primerDiaPosible,
                          LocalDate fechaLimite, LocalDate fechaTardia, String mesPresupuestal,
                          RecibidoDto recibido) {

        public static PagoDto de(PagoProyectado p, PagoRecibido recibido) {
            return new PagoDto(p.mesDePago().toString(), p.desde(), p.hasta(),
                    p.diasCubiertos(), p.esProrrateado(), p.montoOriginal(), p.comisiones(),
                    p.montoPesos(), p.primerDiaPosible(), p.fechaLimite(), p.fechaTardia(),
                    p.mesPresupuestal().toString(),
                    recibido == null ? null : RecibidoDto.de(recibido));
        }

        public static PagoDto de(PagoProyectado p) {
            return de(p, null);
        }
    }

    /** Lo que de verdad llegó de un pago, con la tasa que efectivamente se aplicó. */
    public record RecibidoDto(String mesDePago, BigDecimal montoOriginal, BigDecimal montoPesos,
                              LocalDate fecha, BigDecimal tasaEfectiva) {

        public static RecibidoDto de(PagoRecibido r) {
            return new RecibidoDto(r.getMesDePago().toString(), r.getMontoOriginal(),
                    r.getMontoPesos(), r.getFecha(), r.tasaEfectiva());
        }
    }

    /** La TRM oficial vigente. */
    public record TrmDto(BigDecimal valor, LocalDate vigenteDesde, LocalDate vigenteHasta,
                         String fuente) {

        public static TrmDto de(ClienteTrm.Trm t) {
            return new TrmDto(t.valor(), t.vigenteDesde(), t.vigenteHasta(),
                    "Superintendencia Financiera de Colombia (datos.gov.co)");
        }
    }

    public record CrearFuenteRequest(
            @NotBlank @Size(max = 80) String nombre,
            @NotNull @Positive BigDecimal montoMensual,
            @NotNull LocalDate fechaInicio,
            LocalDate fechaFin,
            MedioCobro medio,
            @Size(max = 60) String cuentaDestino,
            Integer diasHabilesPago,
            Integer diasTolerancia,
            @Positive BigDecimal trm,
            LocalDate trmFecha,
            BigDecimal comisionPorcentaje,
            BigDecimal comisionFija,
            BigDecimal descuentoCambioPorcentaje,
            BigDecimal costoRetiro,
            String notas,
            Boolean trmAutomatica) {

        public ServicioSueldo.Cambios comoCambios() {
            return new ServicioSueldo.Cambios(nombre, montoMensual, fechaInicio, fechaFin, null,
                    medio, cuentaDestino, diasHabilesPago, diasTolerancia, trm, trmFecha,
                    comisionPorcentaje, comisionFija, descuentoCambioPorcentaje, costoRetiro,
                    true, notas, trmAutomatica);
        }
    }

    public record ActualizarFuenteRequest(
            @Size(min = 1, max = 80) String nombre,
            @Positive BigDecimal montoMensual,
            LocalDate fechaInicio,
            LocalDate fechaFin,
            Boolean quitarFechaFin,
            MedioCobro medio,
            @Size(max = 60) String cuentaDestino,
            Integer diasHabilesPago,
            Integer diasTolerancia,
            @Positive BigDecimal trm,
            LocalDate trmFecha,
            BigDecimal comisionPorcentaje,
            BigDecimal comisionFija,
            BigDecimal descuentoCambioPorcentaje,
            BigDecimal costoRetiro,
            Boolean activo,
            String notas,
            Boolean trmAutomatica) {

        public ServicioSueldo.Cambios comoCambios() {
            return new ServicioSueldo.Cambios(nombre, montoMensual, fechaInicio, fechaFin,
                    quitarFechaFin, medio, cuentaDestino, diasHabilesPago, diasTolerancia, trm,
                    trmFecha, comisionPorcentaje, comisionFija, descuentoCambioPorcentaje,
                    costoRetiro, activo, notas, trmAutomatica);
        }
    }

    /**
     * Lo que llegó de un pago.
     *
     * @param montoOriginal solo si difiere de lo proyectado (un pago parcial o con ajuste)
     */
    public record RegistrarPagoRequest(
            @NotNull @Pattern(regexp = "\\d{4}-\\d{2}") String mesDePago,
            @NotNull @Positive BigDecimal montoPesos,
            LocalDate fecha,
            @Positive BigDecimal montoOriginal) {
    }

    /** Un mes cuyo sueldo base se actualizó con la proyección. */
    public record MesAplicadoDto(String periodo, BigDecimal ingresoBase) {
    }
}
