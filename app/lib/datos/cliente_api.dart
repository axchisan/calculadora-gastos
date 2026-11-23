import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/configuracion.dart';
import 'almacen_sesion.dart';
import 'cache_local.dart';
import 'cola_pendientes.dart';

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
  ClienteApi(
    this._almacen, {
    Dio? dio,
    this.alPerderSesion,
    CacheLocal? cache,
    DateTime Function()? reloj,
  }) : _dio = dio ?? Dio(),
       _cache = cache, // ignore: prefer_initializing_formals
       _ahora = reloj ?? DateTime.now {
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

  /// Copia local de las lecturas. Sin ella, el cliente se comporta como antes: todo al servidor.
  final CacheLocal? _cache;
  final DateTime Function() _ahora;

  /// Rutas cuya versión guardada acaba de cambiar tras pedirla de nuevo al servidor. `*`
  /// significa «todo»: se emite al recuperar la conexión.
  final StreamController<String> _actualizaciones =
      StreamController<String>.broadcast();

  /// Se emite tras cada cambio hecho desde esta app (enviado o en cola). Lo escuchan las
  /// lecturas que juntan datos de varias secciones, como Inicio, que no tienen otra forma de
  /// enterarse de que algo se apuntó en otra pantalla.
  final StreamController<void> _cambiosLocales =
      StreamController<void>.broadcast();

  final StreamController<EstadoRed> _cambiosDeRed =
      StreamController<EstadoRed>.broadcast();

  EstadoRed _red = const EstadoRed.enLinea();

  /// Momento del último cambio hecho desde esta app. Lo guardado antes de él puede no reflejarlo.
  DateTime? _ultimoCambio;

  /// Cuándo se revalidó cada lectura, para no repetir la misma petición en ráfaga.
  final Map<String, DateTime> _revalidadoEn = {};
  final Set<String> _revalidando = {};
  Timer? _vigiaDeRed;
  Future<void>? _sincronizacion;

  /// Tras revalidar una lectura, no se vuelve a pedir durante este tiempo aunque se lea otra vez.
  static const Duration _respiroEntreRevalidaciones = Duration(seconds: 20);

  /// Se invoca cuando la sesión ya no puede renovarse, para que la app lleve al login.
  ///
  /// Se puede asignar después de crear el cliente: quien lo conecta es el controlador de la
  /// sesión, que se crea más tarde y depende del propio cliente.
  void Function()? alPerderSesion;

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

  /// Lee del servidor, con la copia local como respaldo y como adelanto.
  ///
  /// - Sin nada guardado: va al servidor y guarda la respuesta.
  /// - Con algo guardado de antes del último cambio hecho en la app: va primero al servidor,
  ///   para no enseñar datos anteriores a ese cambio, y usa lo guardado solo si no hay red.
  /// - En cualquier otro caso devuelve lo guardado al instante y pide la versión nueva por
  ///   detrás. Si llega distinta, la guarda y avisa por [actualizaciones] para que la pantalla
  ///   se repinte.
  ///
  /// Así cada pestaña abre al momento, también sin conexión y aunque Lambda arranque en frío.
  Future<T> obtener<T>(String ruta, {Map<String, dynamic>? parametros}) async {
    final cache = _cache;
    final usuario = _sesion?.usuarioId;
    if (cache == null || usuario == null) {
      return _peticion<T>(() => _dio.get(ruta, queryParameters: parametros));
    }

    final rutaCompleta = _rutaCompleta(ruta, parametros);
    return _superponer(
      rutaCompleta,
      await _leerConCache<T>(ruta, parametros, rutaCompleta, usuario, cache),
    );
  }

  Future<T> _leerConCache<T>(
    String ruta,
    Map<String, dynamic>? parametros,
    String rutaCompleta,
    String usuario,
    CacheLocal cache,
  ) async {
    final clave = 'api|$usuario|$rutaCompleta';
    final guardado = cache.leer(clave);

    // Con una copia y su huella, el servidor contesta 304 sin cuerpo si nada cambió.
    Future<_Lectura> pedir() async {
      final etag = guardado?.etag;
      final respuesta = await _respuesta(
        () => _dio.get(
          ruta,
          queryParameters: parametros,
          options: Options(
            extra: {_lecturaRapida: guardado != null},
            headers: {'If-None-Match': ?etag},
          ),
        ),
      );
      if (respuesta.statusCode == 304 && guardado != null) {
        return _Lectura(guardado.datos, etag, sinCambios: true);
      }
      return _Lectura(respuesta.data, respuesta.headers.value('etag'));
    }

    Future<T> pedirYGuardar() async {
      final lectura = await pedir();
      await _guardar(clave, lectura);
      return lectura.datos as T;
    }

    if (guardado == null) return pedirYGuardar();

    final cambio = _ultimoCambio;
    if (cambio != null && guardado.guardadoEn.isBefore(cambio)) {
      try {
        return await pedirYGuardar();
      } on ErrorApi catch (e) {
        if (!e.esDeConexion) rethrow;
        return guardado.datos as T;
      }
    }

    unawaited(_revalidar(clave, rutaCompleta, guardado, pedir));
    return guardado.datos as T;
  }

  Future<void> _guardar(String clave, _Lectura lectura) async {
    await _cache?.guardar(
      clave,
      lectura.datos as Object,
      guardadoEn: _ahora(),
      etag: lectura.etag,
    );
    _revalidadoEn[clave] = _ahora();
  }

  Future<void> _revalidar(
    String clave,
    String ruta,
    ContenidoCache guardado,
    Future<_Lectura> Function() pedir,
  ) async {
    final ultima = _revalidadoEn[clave];
    if (_revalidando.contains(clave) ||
        (ultima != null &&
            _ahora().difference(ultima) < _respiroEntreRevalidaciones)) {
      return;
    }
    _revalidando.add(clave);
    try {
      final lectura = await pedir();
      // Un 304 confirma la copia: se renueva su fecha y no hay nada que repintar.
      final cambio =
          !lectura.sinCambios &&
          jsonEncode(lectura.datos) != jsonEncode(guardado.datos);
      await _guardar(clave, lectura);
      if (cambio) _actualizaciones.add(ruta);
    } on ErrorApi catch (e) {
      // Sin red, lo guardado sigue valiendo. Cualquier otra respuesta (lo pedido ya no existe,
      // no hay permiso) invalida la copia: la siguiente lectura irá al servidor y mostrará el
      // problema real en vez de esconderlo tras datos viejos.
      if (!e.esDeConexion) {
        await _cache?.borrar(clave);
        _actualizaciones.add(ruta);
      }
    } on SesionExpirada {
      // La pérdida de sesión ya se gestiona en la petición.
    } finally {
      _revalidando.remove(clave);
    }
  }

  /// Cada vez que la app cambia algo en el servidor o lo deja en cola.
  Stream<void> get cambiosLocales => _cambiosLocales.stream;

  /// Rutas leídas cuya versión guardada cambió; `*` cuando hay que revisar todo.
  Stream<String> get actualizaciones => _actualizaciones.stream;

  /// Si hay conexión con el servidor y desde cuándo no la hay.
  EstadoRed get red => _red;
  Stream<EstadoRed> get cambiosDeRed => _cambiosDeRed.stream;

  /// Vuelve a pedir todo lo guardado: al volver la app a primer plano o al tirar para refrescar.
  void revisarTodo() {
    _revalidadoEn.clear();
    _actualizaciones.add('*');
  }

  /// Envía un alta o un cambio.
  ///
  /// Con [sinConexion], si no hay red la operación no falla: se guarda en la cola, aparece en
  /// las listas con la superposición indicada y se envía sola al volver la conexión. Se usa
  /// solo para lo del día a día que tiene identificador propio (apuntar compras, ingresos y
  /// gastos, marcar un gasto como pagado), donde reenviar no duplica nada.
  Future<T> publicar<T>(
    String ruta, {
    Object? cuerpo,
    Superposicion? sinConexion,
    String? descripcion,
  }) => _cambiar<T>(
    () => _dio.post(ruta, data: cuerpo),
    encolable: sinConexion == null
        ? null
        : OperacionPendiente(
            id: (cuerpo is Map && cuerpo['id'] is String)
                ? cuerpo['id'] as String
                : '${_ahora().microsecondsSinceEpoch}',
            metodo: 'POST',
            ruta: ruta,
            cuerpo: cuerpo,
            descripcion: descripcion ?? ruta,
            creadaEn: _ahora(),
            superposicion: sinConexion,
          ),
  );

  Future<T> modificar<T>(String ruta, {Object? cuerpo}) =>
      _cambiar<T>(() => _dio.patch(ruta, data: cuerpo));

  Future<T> reemplazar<T>(String ruta, {Object? cuerpo}) =>
      _cambiar<T>(() => _dio.put(ruta, data: cuerpo));

  Future<void> eliminar(String ruta) => _cambiar<void>(() => _dio.delete(ruta));

  /// Un cambio deja desfasado lo guardado: a partir de aquí, cada lectura irá primero al
  /// servidor hasta que se renueve.
  Future<T> _cambiar<T>(
    Future<Response<dynamic>> Function() enviar, {
    OperacionPendiente? encolable,
  }) async {
    // Lo apuntado antes sin conexión va primero: si no, un cambio sobre algo que el servidor
    // aún no tiene fallaría.
    if (pendientes.isNotEmpty && _red.enLinea) await sincronizar();

    try {
      final resultado = await _peticion<T>(enviar);
      _ultimoCambio = _ahora();
      _revalidadoEn.clear();
      _cambiosLocales.add(null);
      return resultado;
    } on ErrorApi catch (e) {
      if (encolable == null || !e.esDeConexion) rethrow;
      await _encolar(encolable);
      return encolable.superposicion!.datos as T;
    }
  }

  // --- cola de lo apuntado sin conexión ---

  /// Al arrancar: anuncia cuántos cambios esperan y trata de enviarlos.
  void iniciarCola() {
    _publicarEstadoCola();
    if (pendientes.isNotEmpty) unawaited(sincronizar());
  }

  /// Lo que espera a enviarse, incluido lo que el servidor rechazó.
  List<OperacionPendiente> get pendientes {
    final usuario = _sesion?.usuarioId;
    final cache = _cache;
    if (usuario == null || cache == null) return const [];
    return cache.cola.leer(usuario);
  }

  Future<void> _encolar(OperacionPendiente operacion) async {
    final usuario = _sesion!.usuarioId;
    final cola = _cache!.cola;
    await cola.guardar(usuario, [...cola.leer(usuario), operacion]);
    _ultimoCambio = _ahora();
    _publicarEstadoCola();
    _cambiosLocales.add(null);
    for (final s in operacion.superposicion?.todas ?? const <Superposicion>[]) {
      _actualizaciones.add(s.ruta);
    }
  }

  /// Envía en orden lo que quedó en la cola. Se para en cuanto falta la red; lo que el servidor
  /// rechaza por otro motivo queda marcado con el error para que el usuario decida.
  Future<void> sincronizar() {
    return _sincronizacion ??= _sincronizarCola().whenComplete(
      () => _sincronizacion = null,
    );
  }

  Future<void> _sincronizarCola() async {
    final usuario = _sesion?.usuarioId;
    final cache = _cache;
    if (usuario == null || cache == null) return;

    var enviadas = 0;
    for (final operacion in cache.cola.leer(usuario)) {
      if (operacion.error != null) continue;
      try {
        await _peticion<dynamic>(
          () => _dio.request<dynamic>(
            operacion.ruta,
            data: operacion.cuerpo,
            options: Options(method: operacion.metodo),
          ),
        );
        await _quitarDeLaCola(usuario, operacion.id);
        enviadas++;
      } on ErrorApi catch (e) {
        if (e.esDeConexion) break;
        await _reemplazarEnLaCola(usuario, operacion.conError(e.mensaje));
      } on SesionExpirada {
        break;
      }
    }

    if (enviadas > 0) {
      _ultimoCambio = _ahora();
      revisarTodo();
    }
    _publicarEstadoCola();
  }

  /// Vuelve a intentar una operación que el servidor había rechazado.
  Future<void> reintentar(String operacionId) async {
    final usuario = _sesion?.usuarioId;
    if (usuario == null) return;
    final operacion = pendientes.where((o) => o.id == operacionId).firstOrNull;
    if (operacion == null) return;
    await _reemplazarEnLaCola(usuario, operacion.conError(null));
    await sincronizar();
  }

  /// Renuncia a una operación pendiente: deja de mostrarse y no se enviará.
  Future<void> descartar(String operacionId) async {
    final usuario = _sesion?.usuarioId;
    if (usuario == null) return;
    final rutas = pendientes
        .where((o) => o.id == operacionId)
        .firstOrNull
        ?.superposicion
        ?.todas
        .map((s) => s.ruta);
    await _quitarDeLaCola(usuario, operacionId);
    _publicarEstadoCola();
    rutas?.forEach(_actualizaciones.add);
  }

  Future<void> _quitarDeLaCola(String usuario, String id) async {
    final cola = _cache!.cola;
    await cola.guardar(
      usuario,
      cola.leer(usuario).where((o) => o.id != id).toList(),
    );
  }

  Future<void> _reemplazarEnLaCola(
    String usuario,
    OperacionPendiente operacion,
  ) async {
    final cola = _cache!.cola;
    await cola.guardar(usuario, [
      for (final o in cola.leer(usuario)) o.id == operacion.id ? operacion : o,
    ]);
  }

  void _publicarEstadoCola() {
    final cola = pendientes;
    _red = _red.conCola(
      porSubir: cola.where((o) => o.error == null).length,
      conError: cola.where((o) => o.error != null).length,
    );
    _cambiosDeRed.add(_red);
  }

  /// Mezcla en una lectura lo apuntado sin conexión que pertenece a ella.
  T _superponer<T>(String ruta, T datos) {
    final propias = pendientes
        .map((o) => o.superposicion)
        .whereType<Superposicion>()
        .expand((s) => s.todas)
        .where((s) => s.ruta == ruta)
        .toList();
    if (propias.isEmpty) return datos;

    // Copia profunda: no se toca lo que vive en el caché.
    final copia = jsonDecode(jsonEncode(datos));
    for (final s in propias) {
      final lista = s.campoLista == null
          ? copia as List<dynamic>?
          : (copia as Map<String, dynamic>)[s.campoLista] as List<dynamic>?;
      if (lista == null) continue;
      if (s.reemplazaId == null) {
        // Puede que ya hubiera llegado y la lectura lo traiga: no se duplica en pantalla.
        if (!lista.any((e) => e is Map && e['id'] == s.datos['id'])) {
          lista.insert(0, s.datos);
        }
      } else {
        final i = lista.indexWhere((e) => e is Map && e['id'] == s.reemplazaId);
        if (i < 0) continue;
        if (s.quitar) {
          lista.removeAt(i);
        } else {
          lista[i] = s.datos;
        }
      }
    }
    return copia as T;
  }

  static const String _lecturaRapida = 'lecturaRapida';

  static String _rutaCompleta(String ruta, Map<String, dynamic>? parametros) {
    if (parametros == null || parametros.isEmpty) return ruta;
    final orden = parametros.keys.toList()..sort();
    return '$ruta?${orden.map((k) => '$k=${parametros[k]}').join('&')}';
  }

  void _marcarEnLinea() {
    _vigiaDeRed?.cancel();
    _vigiaDeRed = null;
    if (_red.enLinea) return;
    _red = _red.enLineaOtraVez();
    _cambiosDeRed.add(_red);
    // Al volver la conexión se envía lo apuntado sin red y se revisa todo lo que se estaba
    // mostrando desde la copia local.
    unawaited(sincronizar());
    revisarTodo();
  }

  void _marcarSinConexion() {
    if (!_red.enLinea) return;
    _red = _red.sinConexion(_ahora());
    _cambiosDeRed.add(_red);
    // Mientras no haya red, se comprueba cada poco si volvió, sin esperar a que el usuario
    // toque algo.
    _vigiaDeRed ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _dio
          .get<dynamic>('/api/salud')
          .then((_) => _marcarEnLinea())
          .catchError((_) => null),
    );
  }

  // --- interno ---

  Future<T> _peticion<T>(Future<Response<dynamic>> Function() enviar) async =>
      (await _respuesta(enviar)).data as T;

  /// Envía la petición, renueva la sesión si hace falta y traduce los errores. Devuelve la
  /// respuesta completa si fue correcta o un 304 (sin cambios).
  Future<Response<dynamic>> _respuesta(
    Future<Response<dynamic>> Function() enviar,
  ) async {
    late Response<dynamic> respuesta;
    try {
      respuesta = await enviar();
      _marcarEnLinea();
    } on DioException catch (e) {
      final error = _traducirFalloDeRed(e);
      if (error.esDeConexion) _marcarSinConexion();
      throw error;
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
    if ((codigo >= 200 && codigo < 300) || codigo == 304) return respuesta;
    throw _traducirError(respuesta);
  }

  void _alEnviar(RequestOptions opciones, RequestInterceptorHandler siguiente) {
    // Con una copia local que enseñar, no tiene sentido esperar 15 s a una red que no está.
    if (opciones.extra[_lecturaRapida] == true) {
      opciones
        ..connectTimeout = const Duration(seconds: 5)
        ..receiveTimeout = const Duration(seconds: 12);
    }
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

/// Lo que trae una lectura: los datos, su huella y si el servidor dijo que no cambiaron.
class _Lectura {
  const _Lectura(this.datos, this.etag, {this.sinCambios = false});

  final dynamic datos;
  final String? etag;
  final bool sinCambios;
}

/// Si hay conexión con el servidor y qué queda por enviar.
class EstadoRed {
  const EstadoRed.enLinea()
    : enLinea = true,
      sinConexionDesde = null,
      porSubir = 0,
      conError = 0;

  const EstadoRed._({
    required this.enLinea,
    required this.sinConexionDesde,
    required this.porSubir,
    required this.conError,
  });

  final bool enLinea;
  final DateTime? sinConexionDesde;

  /// Cambios apuntados sin conexión que esperan a enviarse.
  final int porSubir;

  /// Cambios que el servidor rechazó y esperan una decisión del usuario.
  final int conError;

  EstadoRed sinConexion(DateTime desde) => EstadoRed._(
    enLinea: false,
    sinConexionDesde: desde,
    porSubir: porSubir,
    conError: conError,
  );

  EstadoRed enLineaOtraVez() => EstadoRed._(
    enLinea: true,
    sinConexionDesde: null,
    porSubir: porSubir,
    conError: conError,
  );

  EstadoRed conCola({required int porSubir, required int conError}) =>
      EstadoRed._(
        enLinea: enLinea,
        sinConexionDesde: sinConexionDesde,
        porSubir: porSubir,
        conError: conError,
      );
}
