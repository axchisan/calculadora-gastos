import '../dominio/modelos.dart';
import 'cliente_api.dart';

enum TipoMovimiento {
  aporte('APORTE', 'Aporte'),
  retiro('RETIRO', 'Retiro');

  const TipoMovimiento(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoMovimiento desde(String codigo) =>
      TipoMovimiento.values.firstWhere(
        (t) => t.codigo == codigo,
        orElse: () => TipoMovimiento.aporte,
      );
}

class MovimientoAhorro {
  const MovimientoAhorro({
    required this.id,
    required this.metaId,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.mesId,
    this.nota,
  });

  final String id;
  final String metaId;
  final TipoMovimiento tipo;
  final double monto;
  final DateTime fecha;
  final String? mesId;
  final String? nota;

  static MovimientoAhorro deJson(Map<String, dynamic> j) => MovimientoAhorro(
    id: j['id'] as String,
    metaId: j['metaId'] as String,
    tipo: TipoMovimiento.desde(j['tipo'] as String),
    monto: (j['monto'] as num).toDouble(),
    fecha: DateTime.parse(j['fecha'] as String),
    mesId: j['mesId'] as String?,
    nota: j['nota'] as String?,
  );
}

/// Reparto propuesto del dinero disponible entre las metas activas.
class Asignacion {
  const Asignacion({
    required this.metaId,
    required this.nombre,
    required this.tipoAsignacion,
    required this.monto,
    this.color,
  });

  final String metaId;
  final String nombre;
  final TipoAsignacion tipoAsignacion;
  final double monto;
  final String? color;

  static Asignacion deJson(Map<String, dynamic> j) => Asignacion(
    metaId: j['metaId'] as String,
    nombre: j['nombre'] as String,
    tipoAsignacion: TipoAsignacion.desde(j['tipoAsignacion'] as String),
    monto: (j['monto'] as num).toDouble(),
    color: j['color'] as String?,
  );
}

/// Metas de ahorro y reparto del excedente.
class RepositorioAhorro {
  const RepositorioAhorro(this._api);

  final ClienteApi _api;

  Future<List<MetaAhorro>> listar() async {
    final datos = await _api.obtener<List<dynamic>>('/api/ahorro/metas');
    return datos
        .map((e) => MetaAhorro.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MetaAhorro> crear({
    required String nombre,
    required TipoAsignacion tipoAsignacion,
    required double valor,
    double? metaMonto,
    String? color,
    int? prioridad,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/ahorro/metas',
      cuerpo: {
        'nombre': nombre,
        'tipoAsignacion': tipoAsignacion.codigo,
        'valor': valor,
        'metaMonto': ?metaMonto,
        'color': ?color,
        'prioridad': ?prioridad,
      },
    );
    return MetaAhorro.deJson(datos);
  }

  Future<MetaAhorro> actualizar(
    String metaId, {
    String? nombre,
    TipoAsignacion? tipoAsignacion,
    double? valor,
    double? metaMonto,
    String? color,
    int? prioridad,
    bool? activa,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/ahorro/metas/$metaId',
      cuerpo: {
        'nombre': ?nombre,
        if (tipoAsignacion != null) 'tipoAsignacion': tipoAsignacion.codigo,
        'valor': ?valor,
        'metaMonto': ?metaMonto,
        'color': ?color,
        'prioridad': ?prioridad,
        'activa': ?activa,
      },
    );
    return MetaAhorro.deJson(datos);
  }

  Future<List<MovimientoAhorro>> movimientos(String metaId) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/ahorro/metas/$metaId/movimientos',
    );
    return datos
        .map((e) => MovimientoAhorro.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MovimientoAhorro> registrarMovimiento(
    String metaId, {
    required TipoMovimiento tipo,
    required double monto,
    DateTime? fecha,
    String? mesId,
    String? nota,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/ahorro/metas/$metaId/movimientos',
      cuerpo: {
        'tipo': tipo.codigo,
        'monto': monto,
        'fecha': ?_fecha(fecha),
        'mesId': ?mesId,
        'nota': ?nota,
      },
    );
    return MovimientoAhorro.deJson(datos);
  }

  Future<void> eliminarMovimiento(String movimientoId) =>
      _api.eliminar('/api/ahorro/movimientos/$movimientoId');

  /// Sugerencia de reparto del disponible del mes.
  ///
  /// **No mueve dinero**: para materializarla hay que registrar los movimientos.
  Future<List<Asignacion>> distribucion(String mesId) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/ahorro/distribucion/$mesId',
    );
    return datos
        .map((e) => Asignacion.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> eliminar(String metaId) =>
      _api.eliminar('/api/ahorro/metas/$metaId');

  static String? _fecha(DateTime? fecha) => fecha == null
      ? null
      : '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}';
}
