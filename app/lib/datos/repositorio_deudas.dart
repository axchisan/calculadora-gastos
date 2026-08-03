import '../dominio/modelos.dart';
import 'cliente_api.dart';

/// Pago realizado a una deuda.
class AbonoDeuda {
  const AbonoDeuda({
    required this.id,
    required this.deudaId,
    required this.monto,
    required this.fecha,
    this.mesId,
    this.nota,
  });

  final String id;
  final String deudaId;
  final double monto;
  final DateTime fecha;

  /// Mes al que se imputa el abono; puede quedar sin vincular.
  final String? mesId;

  final String? nota;

  static AbonoDeuda deJson(Map<String, dynamic> j) => AbonoDeuda(
    id: j['id'] as String,
    deudaId: j['deudaId'] as String,
    monto: (j['monto'] as num).toDouble(),
    fecha: DateTime.parse(j['fecha'] as String),
    mesId: j['mesId'] as String?,
    nota: j['nota'] as String?,
  );
}

/// Deudas externas y sus abonos.
class RepositorioDeudas {
  const RepositorioDeudas(this._api);

  final ClienteApi _api;

  Future<List<Deuda>> listar({bool soloActivas = false}) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/deudas',
      parametros: {'soloActivas': soloActivas},
    );
    return datos.map((e) => Deuda.deJson(e as Map<String, dynamic>)).toList();
  }

  Future<Deuda> crear({
    required String acreedor,
    required TipoDeuda tipo,
    required double montoOriginal,
    DateTime? fechaInicio,
    String? descripcion,
    double? tasaInteresMensual,
    double? cuotaSugerida,
    DateTime? fechaLimite,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/deudas',
      cuerpo: {
        'acreedor': acreedor,
        'tipo': tipo.codigo,
        'montoOriginal': montoOriginal,
        'fechaInicio': ?_fecha(fechaInicio),
        'descripcion': ?descripcion,
        'tasaInteresMensual': ?tasaInteresMensual,
        'cuotaSugerida': ?cuotaSugerida,
        'fechaLimite': ?_fecha(fechaLimite),
      },
    );
    return Deuda.deJson(datos);
  }

  Future<Deuda> actualizar(
    String deudaId, {
    String? acreedor,
    TipoDeuda? tipo,
    String? descripcion,
    double? tasaInteresMensual,
    double? cuotaSugerida,
    DateTime? fechaLimite,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/deudas/$deudaId',
      cuerpo: {
        'acreedor': ?acreedor,
        if (tipo != null) 'tipo': tipo.codigo,
        'descripcion': ?descripcion,
        'tasaInteresMensual': ?tasaInteresMensual,
        'cuotaSugerida': ?cuotaSugerida,
        'fechaLimite': ?_fecha(fechaLimite),
      },
    );
    return Deuda.deJson(datos);
  }

  Future<List<AbonoDeuda>> abonos(String deudaId) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/deudas/$deudaId/abonos',
    );
    return datos
        .map((e) => AbonoDeuda.deJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Registra un abono y descuenta el saldo.
  ///
  /// Vincularlo a un mes hace que se descuente del disponible de ese mes; sin [mesId] solo
  /// reduce la deuda.
  Future<AbonoDeuda> abonar(
    String deudaId, {
    required double monto,
    DateTime? fecha,
    String? mesId,
    String? nota,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/deudas/$deudaId/abonos',
      cuerpo: {
        'monto': monto,
        'fecha': ?_fecha(fecha),
        'mesId': ?mesId,
        'nota': ?nota,
      },
    );
    return AbonoDeuda.deJson(datos);
  }

  Future<void> eliminarAbono(String abonoId) =>
      _api.eliminar('/api/deudas/abonos/$abonoId');

  Future<void> eliminar(String deudaId) =>
      _api.eliminar('/api/deudas/$deudaId');

  static String? _fecha(DateTime? fecha) => fecha == null
      ? null
      : '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}';
}
