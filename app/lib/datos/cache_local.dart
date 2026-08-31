import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  /// Pasado este tiempo, el contenido guardado se considera solo un adelanto mientras llega la
  /// respuesta real, y nunca sustituto de ella.
  static const Duration validez = Duration(hours: 12);

  final SharedPreferences _prefs;

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

  Future<void> guardar(String clave, Object datos) async {
    await _prefs.setString(
      '$_prefijo$clave',
      jsonEncode({
        'guardadoEn': DateTime.now().toIso8601String(),
        'datos': datos,
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
      );
    } on FormatException {
      // Un formato ilegible solo puede venir de una versión anterior de la aplicación.
      _prefs.remove('$_prefijo$clave');
      return null;
    }
  }

  /// Borra todo el caché. Se invoca al cerrar sesión para no dejar datos del usuario anterior.
  Future<void> limpiar() async {
    for (final clave in _prefs.getKeys().where((k) => k.startsWith(_prefijo))) {
      await _prefs.remove(clave);
    }
  }
}

class ContenidoCache {
  const ContenidoCache({required this.datos, required this.guardadoEn});

  final dynamic datos;
  final DateTime guardadoEn;

  Duration get antiguedad => DateTime.now().difference(guardadoEn);

  bool get estaFresco => antiguedad < CacheLocal.validez;
}
