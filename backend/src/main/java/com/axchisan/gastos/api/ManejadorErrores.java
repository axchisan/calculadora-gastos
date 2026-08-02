package com.axchisan.gastos.api;

import com.axchisan.gastos.seguridad.ExcepcionesAutenticacion;
import com.axchisan.gastos.servicio.RecursoNoEncontrado;
import com.axchisan.gastos.servicio.ServicioGastos;
import com.axchisan.gastos.servicio.ServicioMeses;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Convierte las excepciones en respuestas JSON coherentes.
 *
 * <p>Los mensajes de error de autenticación son deliberadamente genéricos: precisar si falló el
 * correo o la contraseña permitiría enumerar las cuentas registradas.
 */
@RestControllerAdvice
public class ManejadorErrores {

    private static final Logger log = LoggerFactory.getLogger(ManejadorErrores.class);

    @ExceptionHandler(ExcepcionesAutenticacion.CredencialesInvalidas.class)
    public ResponseEntity<Map<String, Object>> credencialesInvalidas(
            ExcepcionesAutenticacion.CredencialesInvalidas e) {
        return respuesta(HttpStatus.UNAUTHORIZED, "credenciales_invalidas", e.getMessage());
    }

    @ExceptionHandler(ExcepcionesAutenticacion.EmailYaRegistrado.class)
    public ResponseEntity<Map<String, Object>> emailYaRegistrado(
            ExcepcionesAutenticacion.EmailYaRegistrado e) {
        return respuesta(HttpStatus.CONFLICT, "email_ya_registrado", e.getMessage());
    }

    @ExceptionHandler(ExcepcionesAutenticacion.TokenInvalido.class)
    public ResponseEntity<Map<String, Object>> tokenInvalido(
            ExcepcionesAutenticacion.TokenInvalido e) {
        return respuesta(HttpStatus.UNAUTHORIZED, "token_invalido", e.getMessage());
    }

    @ExceptionHandler(ExcepcionesAutenticacion.DemasiadosIntentos.class)
    public ResponseEntity<Map<String, Object>> demasiadosIntentos(
            ExcepcionesAutenticacion.DemasiadosIntentos e) {
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header("Retry-After", String.valueOf(e.getSegundosEspera()))
                .body(cuerpo("demasiados_intentos", e.getMessage()));
    }

    @ExceptionHandler(RecursoNoEncontrado.class)
    public ResponseEntity<Map<String, Object>> noEncontrado(RecursoNoEncontrado e) {
        return respuesta(HttpStatus.NOT_FOUND, "no_encontrado", e.getMessage());
    }

    @ExceptionHandler(ServicioMeses.MesYaExiste.class)
    public ResponseEntity<Map<String, Object>> mesDuplicado(ServicioMeses.MesYaExiste e) {
        return respuesta(HttpStatus.CONFLICT, "mes_ya_existe", e.getMessage());
    }

    @ExceptionHandler(ServicioMeses.MesCerrado.class)
    public ResponseEntity<Map<String, Object>> mesCerrado(ServicioMeses.MesCerrado e) {
        return respuesta(HttpStatus.CONFLICT, "mes_cerrado", e.getMessage());
    }

    @ExceptionHandler(ServicioGastos.GastoNoEditable.class)
    public ResponseEntity<Map<String, Object>> gastoNoEditable(ServicioGastos.GastoNoEditable e) {
        return respuesta(HttpStatus.CONFLICT, "gasto_no_editable", e.getMessage());
    }

    /** Errores de validación de los datos recibidos, campo por campo. */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> validacion(MethodArgumentNotValidException e) {
        Map<String, String> campos = new LinkedHashMap<>();
        e.getBindingResult().getFieldErrors()
                .forEach(error -> campos.putIfAbsent(error.getField(), error.getDefaultMessage()));

        Map<String, Object> cuerpo = cuerpo("datos_invalidos", "Revisa los datos enviados");
        cuerpo.put("campos", campos);
        return ResponseEntity.badRequest().body(cuerpo);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> argumentoInvalido(IllegalArgumentException e) {
        return respuesta(HttpStatus.BAD_REQUEST, "peticion_invalida", e.getMessage());
    }

    /**
     * Red de seguridad para lo no previsto: se registra con traza completa, pero al cliente solo
     * se le devuelve un mensaje genérico, sin detalles internos.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> errorInesperado(Exception e) {
        log.error("Error no controlado", e);
        return respuesta(HttpStatus.INTERNAL_SERVER_ERROR, "error_interno",
                "Ocurrió un error inesperado");
    }

    private ResponseEntity<Map<String, Object>> respuesta(HttpStatus estado, String codigo,
                                                          String mensaje) {
        return ResponseEntity.status(estado).body(cuerpo(codigo, mensaje));
    }

    private Map<String, Object> cuerpo(String codigo, String mensaje) {
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("error", codigo);
        cuerpo.put("mensaje", mensaje);
        return cuerpo;
    }
}
