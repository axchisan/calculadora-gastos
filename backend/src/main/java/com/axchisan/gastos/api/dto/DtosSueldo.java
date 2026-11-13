package com.axchisan.gastos.api.dto;

import com.axchisan.gastos.dominio.FuenteIngreso;
import com.axchisan.gastos.dominio.MedioCobro;
import com.axchisan.gastos.servicio.ServicioSueldo;
import com.axchisan.gastos.sueldo.PagoProyectado;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Datos de entrada y salida de los ingresos en otra moneda. */
public final class DtosSueldo {

    private DtosSueldo() {
    }

    public record FuenteDto(UUID id, String nombre, String moneda, BigDecimal montoMensual,
                            LocalDate fechaInicio, LocalDate fechaFin, MedioCobro medio,
                            String cuentaDestino, int diasHabilesPago, int diasTolerancia,
                            BigDecimal trm, LocalDate trmFecha, BigDecimal comisionPorcentaje,
                            BigDecimal comisionFija, BigDecimal descuentoCambioPorcentaje,
                            BigDecimal costoRetiro, boolean activo, String notas,
                            List<PagoDto> proximosPagos) {

        public static FuenteDto de(FuenteIngreso f, List<PagoProyectado> pagos) {
            return new FuenteDto(f.getId(), f.getNombre(), f.getMoneda(), f.getMontoMensual(),
                    f.getFechaInicio(), f.getFechaFin(), f.getMedio(), f.getCuentaDestino(),
                    f.getDiasHabilesPago(), f.getDiasTolerancia(), f.getTrmReferencia(),
                    f.getTrmFecha(), f.getComisionPorcentaje(), f.getComisionFija(),
                    f.getDescuentoCambioPorcentaje(), f.getCostoRetiro(), f.isActivo(),
                    f.getNotas(), pagos.stream().map(PagoDto::de).toList());
        }
    }

    public record PagoDto(String mesDePago, LocalDate desde, LocalDate hasta, int diasCubiertos,
                          boolean prorrateado, BigDecimal montoOriginal, BigDecimal comisiones,
                          BigDecimal montoPesos, LocalDate primerDiaPosible,
                          LocalDate fechaLimite, LocalDate fechaTardia, String mesPresupuestal) {

        public static PagoDto de(PagoProyectado p) {
            return new PagoDto(p.mesDePago().toString(), p.desde(), p.hasta(),
                    p.diasCubiertos(), p.esProrrateado(), p.montoOriginal(), p.comisiones(),
                    p.montoPesos(), p.primerDiaPosible(), p.fechaLimite(), p.fechaTardia(),
                    p.mesPresupuestal().toString());
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
            @NotNull @Positive BigDecimal trm,
            LocalDate trmFecha,
            BigDecimal comisionPorcentaje,
            BigDecimal comisionFija,
            BigDecimal descuentoCambioPorcentaje,
            BigDecimal costoRetiro,
            String notas) {

        public ServicioSueldo.Cambios comoCambios() {
            return new ServicioSueldo.Cambios(nombre, montoMensual, fechaInicio, fechaFin, null,
                    medio, cuentaDestino, diasHabilesPago, diasTolerancia, trm, trmFecha,
                    comisionPorcentaje, comisionFija, descuentoCambioPorcentaje, costoRetiro,
                    true, notas);
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
            String notas) {

        public ServicioSueldo.Cambios comoCambios() {
            return new ServicioSueldo.Cambios(nombre, montoMensual, fechaInicio, fechaFin,
                    quitarFechaFin, medio, cuentaDestino, diasHabilesPago, diasTolerancia, trm,
                    trmFecha, comisionPorcentaje, comisionFija, descuentoCambioPorcentaje,
                    costoRetiro, activo, notas);
        }
    }

    /** Un mes cuyo sueldo base se actualizó con la proyección. */
    public record MesAplicadoDto(String periodo, BigDecimal ingresoBase) {
    }
}
