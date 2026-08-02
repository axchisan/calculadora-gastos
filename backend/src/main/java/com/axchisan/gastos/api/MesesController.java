package com.axchisan.gastos.api;

import com.axchisan.gastos.api.dto.DtosMes.ActualizarMesRequest;
import com.axchisan.gastos.api.dto.DtosMes.CrearIngresoRequest;
import com.axchisan.gastos.api.dto.DtosMes.CrearMesRequest;
import com.axchisan.gastos.api.dto.DtosMes.IngresoDto;
import com.axchisan.gastos.api.dto.DtosMes.MesDto;
import com.axchisan.gastos.dominio.Ingreso;
import com.axchisan.gastos.dominio.MesPresupuestal;
import com.axchisan.gastos.repositorio.IngresoRepository;
import com.axchisan.gastos.repositorio.MesPresupuestalRepository;
import com.axchisan.gastos.seguridad.UsuarioActual;
import com.axchisan.gastos.servicio.RecursoNoEncontrado;
import com.axchisan.gastos.servicio.ResumenMensual;
import com.axchisan.gastos.servicio.ServicioMeses;
import com.axchisan.gastos.servicio.ServicioResumen;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/meses")
@Tag(name = "Meses", description = "Presupuesto mensual: sueldo, ingresos extra y resumen")
public class MesesController {

    private final ServicioMeses meses;
    private final ServicioResumen resumen;
    private final MesPresupuestalRepository repositorio;
    private final IngresoRepository ingresos;

    public MesesController(ServicioMeses meses, ServicioResumen resumen,
                           MesPresupuestalRepository repositorio, IngresoRepository ingresos) {
        this.meses = meses;
        this.resumen = resumen;
        this.repositorio = repositorio;
        this.ingresos = ingresos;
    }

    @GetMapping
    @Operation(summary = "Lista los meses registrados, del más reciente al más antiguo")
    public List<MesDto> listar() {
        return meses.listar(UsuarioActual.id()).stream().map(MesDto::de).toList();
    }

    @PostMapping
    @Operation(summary = "Crea un mes copiando los gastos fijos y precalculando el transporte")
    public ResponseEntity<MesDto> crear(@Valid @RequestBody CrearMesRequest peticion) {
        MesPresupuestal mes = meses.crear(UsuarioActual.id(), peticion.periodo(),
                peticion.ingresoBase(), peticion.valorPasaje());
        return ResponseEntity.status(HttpStatus.CREATED).body(MesDto.de(mes));
    }

    @GetMapping("/{mesId}")
    @Operation(summary = "Devuelve un mes")
    public MesDto obtener(@PathVariable UUID mesId) {
        return MesDto.de(meses.buscar(UsuarioActual.id(), mesId));
    }

    @GetMapping("/periodo/{anio}/{mes}")
    @Operation(summary = "Devuelve el mes de un periodo concreto")
    public MesDto porPeriodo(@PathVariable int anio, @PathVariable int mes) {
        return MesDto.de(meses.buscarPorPeriodo(UsuarioActual.id(), YearMonth.of(anio, mes)));
    }

    @GetMapping("/{mesId}/resumen")
    @Operation(summary = "Estado financiero completo del mes")
    public ResumenMensual resumen(@PathVariable UUID mesId) {
        return resumen.del(UsuarioActual.id(), mesId);
    }

    @GetMapping("/evolucion")
    @Operation(summary = "Serie histórica de resúmenes, para las gráficas de evolución")
    public List<ResumenMensual> evolucion(
            @RequestParam(required = false) Integer anio,
            @RequestParam(required = false) Integer mes) {
        // Por defecto, los doce meses anteriores al actual.
        YearMonth desde = anio != null && mes != null
                ? YearMonth.of(anio, mes)
                : YearMonth.now().minusMonths(12);
        return resumen.evolucion(UsuarioActual.id(), desde);
    }

    @PatchMapping("/{mesId}")
    @Operation(summary = "Actualiza el sueldo o las notas del mes")
    public MesDto actualizar(@PathVariable UUID mesId,
                             @Valid @RequestBody ActualizarMesRequest peticion) {
        UUID usuarioId = UsuarioActual.id();
        if (peticion.ingresoBase() != null) {
            meses.actualizarIngreso(usuarioId, mesId, peticion.ingresoBase());
        }
        if (peticion.notas() != null) {
            meses.actualizarNotas(usuarioId, mesId, peticion.notas());
        }
        return MesDto.de(meses.buscar(usuarioId, mesId));
    }

    @PostMapping("/{mesId}/cerrar")
    @Operation(summary = "Cierra el mes y lo deja como registro histórico")
    public MesDto cerrar(@PathVariable UUID mesId) {
        return MesDto.de(meses.cerrar(UsuarioActual.id(), mesId));
    }

    @PostMapping("/{mesId}/reabrir")
    @Operation(summary = "Reabre un mes cerrado para poder modificarlo")
    public MesDto reabrir(@PathVariable UUID mesId) {
        return MesDto.de(meses.reabrir(UsuarioActual.id(), mesId));
    }

    @DeleteMapping("/{mesId}")
    @Operation(summary = "Elimina el mes y todo su contenido")
    public ResponseEntity<Void> eliminar(@PathVariable UUID mesId) {
        meses.eliminar(UsuarioActual.id(), mesId);
        return ResponseEntity.noContent().build();
    }

    // --- ingresos adicionales ---

    @GetMapping("/{mesId}/ingresos")
    @Operation(summary = "Lista los ingresos extra del mes")
    public List<IngresoDto> listarIngresos(@PathVariable UUID mesId) {
        meses.buscar(UsuarioActual.id(), mesId);
        return ingresos.listarDelMes(mesId).stream().map(IngresoDto::de).toList();
    }

    @PostMapping("/{mesId}/ingresos")
    @Transactional
    @Operation(summary = "Registra un ingreso extra: prima, bono o trabajo adicional")
    public ResponseEntity<IngresoDto> crearIngreso(@PathVariable UUID mesId,
                                                   @Valid @RequestBody CrearIngresoRequest peticion) {
        MesPresupuestal mes = meses.buscar(UsuarioActual.id(), mesId);
        Ingreso ingreso = new Ingreso(
                peticion.concepto(),
                peticion.monto(),
                peticion.fecha() == null ? LocalDate.now() : peticion.fecha(),
                Boolean.TRUE.equals(peticion.recibido()));
        mes.agregarIngreso(ingreso);
        repositorio.save(mes);
        return ResponseEntity.status(HttpStatus.CREATED).body(IngresoDto.de(ingreso));
    }

    @PatchMapping("/ingresos/{ingresoId}/recibido")
    @Transactional
    @Operation(summary = "Marca un ingreso extra como cobrado o pendiente")
    public IngresoDto marcarRecibido(@PathVariable UUID ingresoId,
                                     @RequestParam boolean recibido) {
        Ingreso ingreso = ingresos.buscarDelUsuario(UsuarioActual.id(), ingresoId)
                .orElseThrow(() -> new RecursoNoEncontrado("el ingreso", ingresoId));
        ingreso.setRecibido(recibido);
        return IngresoDto.de(ingresos.save(ingreso));
    }

    @DeleteMapping("/ingresos/{ingresoId}")
    @Transactional
    @Operation(summary = "Elimina un ingreso extra")
    public ResponseEntity<Void> eliminarIngreso(@PathVariable UUID ingresoId) {
        Ingreso ingreso = ingresos.buscarDelUsuario(UsuarioActual.id(), ingresoId)
                .orElseThrow(() -> new RecursoNoEncontrado("el ingreso", ingresoId));
        ingresos.delete(ingreso);
        return ResponseEntity.noContent().build();
    }
}
