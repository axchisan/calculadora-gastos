import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cola_pendientes.dart';

/// Copia local de las últimas respuestas del servidor.
///
/// Cumple dos funciones. La primera es poder consultar el mes sin conexión. La segunda, y más
/// visible en el día a día, es que la aplicación muestre algo de inmediato al abrirse: la
/// primera petición del día coincide con el arranque en frío de Lambda y con el despertar de
/// la base de datos suspendida, y esperar en blanco un segundo y medio se nota.
///
/// Solo guarda datos de lectura. Las acciones que modifican algo siguen exigiendo conexión: una
/// cola de cambios pendientes traería conflictos de sincronización que no compensan en una
/// aplicación de un solo usuario.
class CacheLocal {
  const CacheLocal._(this._prefs);

  static const String _prefijo = 'cache.';
  static const String _clavePeriodo = 'periodo.elegido';
  static const String _claveTema = 'apariencia.tema';

  /// Pasado este tiempo, el contenido guardado se considera solo un adelanto mientras llega la
  /// respuesta real, y nunca sustituto de ella.
  static const Duration validez = Duration(hours: 12);

  final SharedPreferences _prefs;

  /// La cola de lo apuntado sin conexión, guardada junto al caché pero fuera de su prefijo:
  /// limpiar el caché al cerrar sesión no debe perder cambios sin enviar.
  ColaPendientes get cola => ColaPendientes(_prefs);

  static Future<CacheLocal> abrir() async =>
      CacheLocal._(await SharedPreferences.getInstance());

  /// Guarda el mes que se está viendo, para volver a él en la siguiente apertura.
  ///
  /// Va aparte del resto del caché y sin caducidad: no es una copia de datos del servidor sino
  /// una preferencia, y no tiene sentido que se «pase» a las doce horas.
  Future<void> guardarPeriodo(DateTime periodo) async {
    await _prefs.setString(
      _clavePeriodo,
      '${periodo.year}-${periodo.month.toString().padLeft(2, '0')}',
    );
  }

  /// El último mes visto, o null si nunca se eligió ninguno.
  DateTime? leerPeriodo() {
    final crudo = _prefs.getString(_clavePeriodo);
    if (crudo == null) return null;

    final partes = crudo.split('-');
    if (partes.length != 2) return null;

    final anio = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    if (anio == null || mes == null || mes < 1 || mes > 12) return null;

    return DateTime(anio, mes);
  }

  /// Guarda el tema elegido: `claro`, `oscuro` o `sistema`.
  ///
  /// Como el mes elegido, es una preferencia y no una copia del servidor: no caduca ni se borra
  /// al cerrar sesión.
  Future<void> guardarTema(String tema) async {
    await _prefs.setString(_claveTema, tema);
  }

  /// El tema elegido, o null si nunca se eligió.
  String? leerTema() => _prefs.getString(_claveTema);

  /// Guarda [datos] bajo [clave]. [guardadoEn] permite usar el mismo reloj que quien compara
  /// después las fechas. [etag] es la huella que dio el servidor, para preguntarle después si
  /// cambió algo sin volver a descargarlo.
  Future<void> guardar(
    String clave,
    Object datos, {
    DateTime? guardadoEn,
    String? etag,
  }) async {
    await _prefs.setString(
      '$_prefijo$clave',
      jsonEncode({
        'guardadoEn': (guardadoEn ?? DateTime.now()).toIso8601String(),
        'datos': datos,
        'etag': ?etag,
      }),
    );
  }

  /// Devuelve lo guardado junto con su antigüedad, o null si no hay nada.
  ContenidoCache? leer(String clave) {
    final crudo = _prefs.getString('$_prefijo$clave');
    if (crudo == null) return null;

    try {
      final envoltorio = jsonDecode(crudo) as Map<String, dynamic>;
      return ContenidoCache(
        datos: envoltorio['datos'],
        guardadoEn: DateTime.parse(envoltorio['guardadoEn'] as String),
        etag: envoltorio['etag'] as String?,
      );
    } on FormatException {
      // Un formato ilegible solo puede venir de una versión anterior de la aplicación.
      _prefs.remove('$_prefijo$clave');
      return null;
    }
  }

  /// Olvida una sola lectura guardada.
  Future<void> borrar(String clave) => _prefs.remove('$_prefijo$clave');

  /// Borra todo el caché. Se invoca al cerrar sesión para no dejar datos del usuario anterior.
  Future<void> limpiar() async {
    for (final clave in _prefs.getKeys().where((k) => k.startsWith(_prefijo))) {
      await _prefs.remove(clave);
    }
  }
}

class ContenidoCache {
  const ContenidoCache({
    required this.datos,
    required this.guardadoEn,
    this.etag,
  });

  final dynamic datos;
  final DateTime guardadoEn;

  /// Huella de esta versión según el servidor; null si se guardó antes de que la diera.
  final String? etag;

  Duration get antiguedad => DateTime.now().difference(guardadoEn);

  bool get estaFresco => antiguedad < CacheLocal.validez;
}
