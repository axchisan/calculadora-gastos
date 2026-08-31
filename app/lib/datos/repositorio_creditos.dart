import '../dominio/credito.dart';
import 'cliente_api.dart';

/// Créditos con cuadro de amortización.
class RepositorioCreditos {
  const RepositorioCreditos(this._api);

  final ClienteApi _api;

  Future<List<Credito>> listar() async {
    final datos = await _api.obtener<List<dynamic>>('/api/creditos');
    return datos.map((e) => Credito.deJson(e as Map<String, dynamic>)).toList();
  }

  Future<Credito> obtener(String creditoId) async {
    final datos = await _api.obtener<Map<String, dynamic>>(
      '/api/creditos/$creditoId',
    );
    return Credito.deJson(datos);
  }

  Future<List<CuotaCredito>> cuotas(String creditoId) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/creditos/$creditoId/cuotas',
    );
    return datos
        .map((e) => CuotaCredito.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarCuota(
    String cuotaId, {
    required bool pagada,
    DateTime? fecha,
    double? monto,
  }) => _api.reemplazar<Map<String, dynamic>>(
    '/api/creditos/cuotas/$cuotaId',
    cuerpo: {'pagada': pagada, 'fecha': ?_fecha(fecha), 'monto': ?monto},
  );

  /// Qué pasaría si se abonara de más a capital.
  Future<SimulacionAbono> simular(
    String creditoId, {
    required double abono,
    required ModoDeAbono modo,
  }) async {
    final datos = await _api.obtener<Map<String, dynamic>>(
      '/api/creditos/$creditoId/simulacion',
      parametros: {'abono': abono, 'modo': modo.codigo},
    );
    return SimulacionAbono.deJson(datos);
  }

  static String? _fecha(DateTime? fecha) => fecha == null
      ? null
      : '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}';
}
