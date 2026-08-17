package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosCompra.ActualizarCompraRequest;
import com.axchisan.gastos.api.dto.DtosCompra.CompraDto;
import com.axchisan.gastos.api.dto.DtosCompra.ComprasDelMesDto;
import com.axchisan.gastos.api.dto.DtosCompra.CorteTarjetaDto;
import com.axchisan.gastos.api.dto.DtosCompra.RegistrarCompraRequest;
import com.axchisan.gastos.api.dto.DtosCompra.SaldarCorteRequest;
import com.axchisan.gastos.dominio.Compra;
import com.axchisan.gastos.dominio.MedioPago;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.ServicioCompras;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import java.util.function.Predicate;
import java.util.stream.Collectors;

/** Las compras del día a día y los cortes de las tarjetas de crédito. */
@RestController
@RequestMapping("/api")
@Tag(name = "Compras", description = "Gastos del día a día y cortes de tarjeta")
public class ComprasController {

    private final ServicioCompras compras;

    public ComprasController(ServicioCompras compras) {
        this.compras = compras;
    }

    @GetMapping("/meses/{mesId}/compras")
    @Operation(summary = "Compras del día a día de un mes, con sus totales")
    public ComprasDelMesDto listar(@PathVariable UUID mesId) {
        List<Compra> lista = compras.listarDelMes(UsuarioActual.id(), mesId);

        BigDecimal total = sumar(lista, c -> true);
        BigDecimal inmediato = sumar(lista, c -> c.getMedio() != MedioPago.CREDITO);
        BigDecimal aCredito = total.subtract(inmediato);

        // El desglose por día se arma aquí y no con una consulta aparte: la lista ya está en
        // memoria y son unas decenas de filas.
        Map<LocalDate, BigDecimal> porFecha = lista.stream()
                .collect(Collectors.groupingBy(Compra::getFecha, TreeMap::new,
                        Collectors.reducing(BigDecimal.ZERO, Compra::getMonto, BigDecimal::add)));

        List<ComprasDelMesDto.TotalDia> porDia = porFecha.entrySet().stream()
                .map(dia -> new ComprasDelMesDto.TotalDia(dia.getKey(), dia.getValue()))
                .toList();

        return new ComprasDelMesDto(total, inmediato, aCredito, porDia,
                lista.stream().map(CompraDto::de).toList());
    }

    @PostMapping("/meses/{mesId}/compras")
    @Operation(summary = "Registra una compra del día a día")
    public ResponseEntity<CompraDto> registrar(@PathVariable UUID mesId,
                                               @Valid @RequestBody RegistrarCompraRequest peticion) {
        Compra compra = compras.registrar(UsuarioActual.id(), mesId, peticion.fecha(),
                peticion.descripcion(), peticion.categoria(), peticion.monto(), peticion.medio(),
                peticion.tarjetaId(), peticion.nota(), null);
        return ResponseEntity.status(HttpStatus.CREATED).body(CompraDto.de(compra));
    }

    @PatchMapping("/compras/{compraId}")
    @Operation(summary = "Modifica una compra")
    public CompraDto actualizar(@PathVariable UUID compraId,
                                @Valid @RequestBody ActualizarCompraRequest peticion) {
        return CompraDto.de(compras.actualizar(UsuarioActual.id(), compraId, peticion.fecha(),
                peticion.descripcion(), peticion.categoria(), peticion.monto(), peticion.medio(),
                peticion.tarjetaId(), peticion.nota()));
    }

    @DeleteMapping("/compras/{compraId}")
    @Operation(summary = "Elimina una compra")
    public ResponseEntity<Void> eliminar(@PathVariable UUID compraId) {
        compras.eliminar(UsuarioActual.id(), compraId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/cortes/{periodo}")
    @Operation(summary = "Cortes de tarjeta que vencen en un mes, en formato aaaa-mm")
    public List<CorteTarjetaDto> cortes(@PathVariable YearMonth periodo) {
        return compras.cortesDe(UsuarioActual.id(), periodo).stream()
                .map(CorteTarjetaDto::de)
                .toList();
    }

    @PutMapping("/cortes/{periodo}/tarjetas/{tarjetaId}")
    @Operation(summary = "Marca el corte de una tarjeta como pagado, o lo devuelve a pendiente")
    public ResponseEntity<Void> saldarCorte(@PathVariable YearMonth periodo,
                                            @PathVariable UUID tarjetaId,
                                            @Valid @RequestBody SaldarCorteRequest peticion) {
        compras.saldarCorte(UsuarioActual.id(), tarjetaId, periodo, peticion.pagado());
        return ResponseEntity.noContent().build();
    }

    private static BigDecimal sumar(List<Compra> compras, Predicate<Compra> filtro) {
        return compras.stream()
                .filter(filtro)
                .map(Compra::getMonto)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
