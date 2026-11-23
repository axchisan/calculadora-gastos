import 'cliente_api.dart';

/// Una clave con la que el teléfono o Gmail envían avisos sin la sesión.
class ClaveIngesta {
  const ClaveIngesta({
    required this.id,
    required this.nombre,
    required this.creada,
    this.usada,
  });

  final String id;
  final String nombre;
  final DateTime creada;
  final DateTime? usada;

  static ClaveIngesta deJson(Map<String, dynamic> j) => ClaveIngesta(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    creada: DateTime.parse(j['creada'] as String).toLocal(),
    usada: j['usada'] == null
        ? null
        : DateTime.parse(j['usada'] as String).toLocal(),
  );
}

/// Lo que dejó un lote de avisos.
class ResultadoLote {
  const ResultadoLote(this.nuevos, this.repetidos, this.ignorados);

  final int nuevos;
  final int repetidos;
  final int ignorados;

  ResultadoLote operator +(ResultadoLote o) => ResultadoLote(
    nuevos + o.nuevos,
    repetidos + o.repetidos,
    ignorados + o.ignorados,
  );
}

class RepositorioIngesta {
  const RepositorioIngesta(this._api);

  final ClienteApi _api;

  Future<List<ClaveIngesta>> claves() async {
    final datos = await _api.obtener<List<dynamic>>('/api/ingesta/claves');
    return datos
        .map((e) => ClaveIngesta.deJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea una clave y devuelve `(id, clave)`. La clave no se puede volver a consultar.
  Future<(String, String)> crearClave(String nombre) async {
    final r = await _api.publicar<Map<String, dynamic>>(
      '/api/ingesta/claves',
      cuerpo: {'nombre': nombre},
    );
    return (r['id'] as String, r['clave'] as String);
  }

  Future<void> revocar(String id) => _api.eliminar('/api/ingesta/claves/$id');

  /// Envía avisos con la sesión, de a 200.
  Future<ResultadoLote> enviar(
    List<String> textos, {
    String origen = 'SMS',
  }) async {
    var total = const ResultadoLote(0, 0, 0);
    for (var i = 0; i < textos.length; i += 200) {
      final parte = textos.skip(i).take(200);
      final r = await _api.publicar<Map<String, dynamic>>(
        '/api/detectados/avisos/lote',
        cuerpo: {
          'avisos': [
            for (final t in parte) {'origen': origen, 'texto': t},
          ],
        },
      );
      total =
          total +
          ResultadoLote(
            (r['nuevos'] as num?)?.toInt() ?? 0,
            (r['repetidos'] as num?)?.toInt() ?? 0,
            ((r['ignorados'] as num?)?.toInt() ?? 0) +
                ((r['noReconocidos'] as num?)?.toInt() ?? 0),
          );
    }
    return total;
  }
}
