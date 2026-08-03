import 'dart:async';

import 'package:dio/dio.dart';

import '../core/configuracion.dart';
import 'almacen_sesion.dart';

/// Error de la API con el mensaje que se puede mostrar al usuario.
class ErrorApi implements Exception {
  const ErrorApi({
    required this.codigo,
    required this.mensaje,
    this.estado,
    this.campos = const {},
  });

  /// Código legible que devuelve el servidor: `credenciales_invalidas`, `mes_cerrado`…
  final String codigo;

  /// Texto pensado para mostrarse tal cual.
  final String mensaje;

  final int? estado;

  /// Errores de validación por campo, cuando el servidor los detalla.
  final Map<String, String> campos;

  bool get esDeAutenticacion => estado == 401;
  bool get esDeConexion => codigo == 'sin_conexion';

  @override
  String toString() => mensaje;
}

/// La sesión caducó y no se pudo renovar: hay que volver a iniciar sesión.
class SesionExpirada implements Exception {
  const SesionExpirada();
}

/// Cliente HTTP de la API.
///
/// Se encarga de tres cosas que, de no estar aquí, habría que repetir en cada pantalla: añadir
/// el token a cada petición, renovarlo cuando caduca sin que el usuario lo note, y traducir los
/// errores del servidor a mensajes en español.
class ClienteApi {
  // El almacén va como parámetro posicional y no nombrado porque Dart no admite parámetros
  // nombrados que empiecen por guion bajo, y solo así puede inicializarse el campo privado
  // directamente desde el constructor.
  ClienteApi(this._almacen, {Dio? dio, this.alPerderSesion})
    : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = Configuracion.urlApi
      ..connectTimeout = Configuracion.esperaConexion
      ..receiveTimeout = Configuracion.esperaRespuesta
      ..headers['Content-Type'] = 'application/json'
      // Se validan todos los estados aquí y se traducen a ErrorApi en un solo sitio.
      ..validateStatus = (_) => true;

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _alEnviar, onError: _alFallar),
    );
  }

  final Dio _dio;
  final AlmacenSesion _almacen;

  /// Se invoca cuando la sesión ya no puede renovarse, para que la app lleve al login.
  final void Function()? alPerderSesion;

  SesionGuardada? _sesion;

  /// Evita que varias peticiones simultáneas disparen varias renovaciones a la vez. Solo la
  /// primera renueva; las demás esperan su resultado.
  Future<void>? _renovacionEnCurso;

  SesionGuardada? get sesion => _sesion;

  bool get haySesion => _sesion != null;

  /// Carga la sesión guardada al arrancar la aplicación.
  Future<SesionGuardada?> cargarSesion() async {
    _sesion = await _almacen.leer();
    return _sesion;
  }

  Future<void> establecerSesion(SesionGuardada sesion) async {
    _sesion = sesion;
    await _almacen.guardar(sesion);
  }

  Future<void> cerrarSesion() async {
    _sesion = null;
    await _almacen.borrar();
  }

  // --- verbos ---

  Future<T> obtener<T>(String ruta, {Map<String, dynamic>? parametros}) =>
      _peticion<T>(() => _dio.get(ruta, queryParameters: parametros));

  Future<T> publicar<T>(String ruta, {Object? cuerpo}) =>
      _peticion<T>(() => _dio.post(ruta, data: cuerpo));

  Future<T> modificar<T>(String ruta, {Object? cuerpo}) =>
      _peticion<T>(() => _dio.patch(ruta, data: cuerpo));

  Future<T> reemplazar<T>(String ruta, {Object? cuerpo}) =>
      _peticion<T>(() => _dio.put(ruta, data: cuerpo));

  Future<void> eliminar(String ruta) =>
      _peticion<void>(() => _dio.delete(ruta));

  // --- interno ---

  Future<T> _peticion<T>(Future<Response<dynamic>> Function() enviar) async {
    late Response<dynamic> respuesta;
    try {
      respuesta = await enviar();
    } on DioException catch (e) {
      throw _traducirFalloDeRed(e);
    }

    // Un 401 puede significar simplemente que el token caducó: se renueva y se reintenta una
    // vez. Si vuelve a fallar, la sesión ya no sirve.
    if (respuesta.statusCode == 401 && _sesion != null) {
      final renovado = await _renovarSesion();
      if (renovado) {
        try {
          respuesta = await enviar();
        } on DioException catch (e) {
          throw _traducirFalloDeRed(e);
        }
      } else {
        await cerrarSesion();
        alPerderSesion?.call();
        throw const SesionExpirada();
      }
    }

    final codigo = respuesta.statusCode ?? 0;
    if (codigo >= 200 && codigo < 300) {
      return respuesta.data as T;
    }
    throw _traducirError(respuesta);
  }

  void _alEnviar(RequestOptions opciones, RequestInterceptorHandler siguiente) {
    final token = _sesion?.accessToken;
    if (token != null && !opciones.path.startsWith('/api/auth/')) {
      opciones.headers['Authorization'] = 'Bearer $token';
    }
    siguiente.next(opciones);
  }

  void _alFallar(DioException error, ErrorInterceptorHandler siguiente) =>
      siguiente.next(error);

  /// Renueva el par de tokens. Devuelve false si el refresco ya no es válido.
  Future<bool> _renovarSesion() async {
    // Si otra petición ya está renovando, se espera a que termine en lugar de lanzar una
    // segunda renovación: el servidor invalidaría el token de la primera.
    if (_renovacionEnCurso != null) {
      await _renovacionEnCurso;
      return _sesion != null;
    }

    final completador = Completer<void>();
    _renovacionEnCurso = completador.future;

    try {
      final actual = _sesion;
      if (actual == null) return false;

      final respuesta = await _dio.post(
        '/api/auth/refresh',
        data: {'refreshToken': actual.refreshToken},
      );

      if (respuesta.statusCode != 200) return false;

      await establecerSesion(
        SesionGuardada.deRespuesta(respuesta.data as Map<String, dynamic>),
      );
      return true;
    } on DioException {
      return false;
    } finally {
      completador.complete();
      _renovacionEnCurso = null;
    }
  }

  ErrorApi _traducirError(Response<dynamic> respuesta) {
    final datos = respuesta.data;
    if (datos is Map<String, dynamic>) {
      return ErrorApi(
        codigo: datos['error'] as String? ?? 'error_desconocido',
        mensaje: datos['mensaje'] as String? ?? 'Ocurrió un error inesperado',
        estado: respuesta.statusCode,
        campos:
            (datos['campos'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            const {},
      );
    }
    return ErrorApi(
      codigo: 'error_desconocido',
      mensaje: 'El servidor respondió de forma inesperada',
      estado: respuesta.statusCode,
    );
  }

  ErrorApi _traducirFalloDeRed(DioException error) {
    final mensaje = switch (error.type) {
      DioExceptionType.connectionTimeout || DioExceptionType.sendTimeout =>
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      DioExceptionType.receiveTimeout =>
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
      DioExceptionType.connectionError => 'Sin conexión a internet.',
      _ => 'No se pudo completar la operación.',
    };
    return ErrorApi(codigo: 'sin_conexion', mensaje: mensaje);
  }
}
