import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cómo se ve en una lista algo que aún no llegó al servidor.
///
/// Al leer [ruta], la app añade [datos] a la lista (o, si hay [reemplazaId], sustituye ese
/// elemento por [datos]). Así lo apuntado sin conexión aparece enseguida donde corresponde.
class Superposicion {
  const Superposicion({
    required this.ruta,
    required this.datos,
    this.campoLista,
    this.reemplazaId,
    this.quitar = false,
    this.tambien = const [],
  });

  /// Ruta de la lectura donde debe aparecer: `/api/meses/<id>/compras`.
  final String ruta;

  /// Si la respuesta es un objeto, el campo que contiene la lista; nulo si es la lista misma.
  final String? campoLista;

  /// Identificador del elemento a sustituir; nulo para añadir uno nuevo.
  final String? reemplazaId;

  /// El elemento tal como lo devolvería el servidor, marcado con `_pendiente`.
  final Map<String, dynamic> datos;

  /// Con [reemplazaId]: en lugar de sustituirlo, lo quita (un gasto pagado sale de «por pagar»).
  final bool quitar;

  /// Otras lecturas donde el mismo cambio debe verse: una compra aparece en las compras del mes
  /// y también en la lista de movimientos.
  final List<Superposicion> tambien;

  /// Esta y las de [tambien], en una sola lista.
  Iterable<Superposicion> get todas sync* {
    yield this;
    for (final s in tambien) {
      yield* s.todas;
    }
  }

  Map<String, dynamic> aJson() => {
    'ruta': ruta,
    'campoLista': campoLista,
    'reemplazaId': reemplazaId,
    'datos': datos,
    if (quitar) 'quitar': true,
    if (tambien.isNotEmpty) 'tambien': [for (final s in tambien) s.aJson()],
  };

  static Superposicion deJson(Map<String, dynamic> j) => Superposicion(
    ruta: j['ruta'] as String,
    campoLista: j['campoLista'] as String?,
    reemplazaId: j['reemplazaId'] as String?,
    datos: (j['datos'] as Map).cast<String, dynamic>(),
    quitar: j['quitar'] == true,
    tambien: [
      for (final t in (j['tambien'] as List<dynamic>? ?? const []))
        Superposicion.deJson((t as Map).cast<String, dynamic>()),
    ],
  );
}

/// Un cambio apuntado sin conexión, esperando a enviarse.
class OperacionPendiente {
  const OperacionPendiente({
    required this.id,
    required this.metodo,
    required this.ruta,
    required this.descripcion,
    required this.creadaEn,
    this.cuerpo,
    this.superposicion,
    this.error,
  });

  final String id;
  final String metodo;
  final String ruta;
  final Object? cuerpo;

  /// Para el usuario: «Compra · Pan · $4.000».
  final String descripcion;
  final DateTime creadaEn;
  final Superposicion? superposicion;

  /// Si el servidor la rechazó (no por falta de red): el motivo. Queda a la vista hasta que el
  /// usuario la reintente o la descarte; nunca se pierde en silencio.
  final String? error;

  OperacionPendiente conError(String? motivo) => OperacionPendiente(
    id: id,
    metodo: metodo,
    ruta: ruta,
    cuerpo: cuerpo,
    descripcion: descripcion,
    creadaEn: creadaEn,
    superposicion: superposicion,
    error: motivo,
  );

  Map<String, dynamic> aJson() => {
    'id': id,
    'metodo': metodo,
    'ruta': ruta,
    'cuerpo': cuerpo,
    'descripcion': descripcion,
    'creadaEn': creadaEn.toIso8601String(),
    'superposicion': superposicion?.aJson(),
    'error': error,
  };

  static OperacionPendiente deJson(Map<String, dynamic> j) =>
      OperacionPendiente(
        id: j['id'] as String,
        metodo: j['metodo'] as String,
        ruta: j['ruta'] as String,
        cuerpo: j['cuerpo'],
        descripcion: j['descripcion'] as String,
        creadaEn: DateTime.parse(j['creadaEn'] as String),
        superposicion: j['superposicion'] == null
            ? null
            : Superposicion.deJson(
                (j['superposicion'] as Map).cast<String, dynamic>(),
              ),
        error: j['error'] as String?,
      );
}

/// Cola persistente de lo apuntado sin conexión, por usuario y en orden de llegada.
///
/// Sobrevive a cerrar la app y a cerrar sesión: lo apuntado es del usuario y debe llegar al
/// servidor cuando vuelva a entrar con conexión.
class ColaPendientes {
  ColaPendientes(this._prefs);

  final SharedPreferences _prefs;

  static String _clave(String usuario) => 'cola.$usuario';

  List<OperacionPendiente> leer(String usuario) {
    final crudo = _prefs.getString(_clave(usuario));
    if (crudo == null) return const [];
    try {
      return (jsonDecode(crudo) as List<dynamic>)
          .map(
            (e) =>
                OperacionPendiente.deJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> guardar(String usuario, List<OperacionPendiente> cola) async {
    if (cola.isEmpty) {
      await _prefs.remove(_clave(usuario));
      return;
    }
    await _prefs.setString(
      _clave(usuario),
      jsonEncode(cola.map((o) => o.aJson()).toList()),
    );
  }
}
