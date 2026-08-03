import '../dominio/modelos.dart';
import 'cliente_api.dart';

/// Acceso a los meses, sus gastos y el resumen.
class RepositorioMeses {
  const RepositorioMeses(this._api);

  final ClienteApi _api;

  Future<List<Mes>> listar() async {
    final datos = await _api.obtener<List<dynamic>>('/api/meses');
    return datos.map((e) => Mes.deJson(e as Map<String, dynamic>)).toList();
  }

  Future<Mes> crear({
    required int anio,
    required int mes,
    double? ingresoBase,
    double? valorPasaje,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses',
      cuerpo: {
        'anio': anio,
        'mes': mes,
        'ingresoBase': ?ingresoBase,
        'valorPasaje': ?valorPasaje,
      },
    );
    return Mes.deJson(datos);
  }

  Future<ResumenMensual> resumen(String mesId) async {
    final datos = await _api.obtener<Map<String, dynamic>>(
      '/api/meses/$mesId/resumen',
    );
    return ResumenMensual.deJson(datos);
  }

  /// Serie histórica para las gráficas de evolución.
  Future<List<ResumenMensual>> evolucion({int? anio, int? mes}) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/meses/evolucion',
      parametros: {'anio': ?anio, 'mes': ?mes},
    );
    return datos
        .map((e) => ResumenMensual.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Mes> actualizarIngreso(String mesId, double ingresoBase) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/$mesId',
      cuerpo: {'ingresoBase': ingresoBase},
    );
    return Mes.deJson(datos);
  }

  Future<Mes> cerrar(String mesId) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses/$mesId/cerrar',
    );
    return Mes.deJson(datos);
  }

  Future<Mes> reabrir(String mesId) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses/$mesId/reabrir',
    );
    return Mes.deJson(datos);
  }

  // --- gastos ---

  Future<List<Gasto>> gastos(String mesId) async {
    final datos = await _api.obtener<List<dynamic>>('/api/meses/$mesId/gastos');
    return datos.map((e) => Gasto.deJson(e as Map<String, dynamic>)).toList();
  }

  Future<Gasto> crearGasto(
    String mesId, {
    required String nombre,
    required CategoriaGasto categoria,
    required double monto,
    int? diaVencimiento,
    String? notas,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses/$mesId/gastos',
      cuerpo: {
        'nombre': nombre,
        'categoria': categoria.codigo,
        'monto': monto,
        'diaVencimiento': ?diaVencimiento,
        'notas': ?notas,
      },
    );
    return Gasto.deJson(datos);
  }

  Future<Gasto> actualizarGasto(
    String gastoId, {
    String? nombre,
    CategoriaGasto? categoria,
    double? monto,
    int? diaVencimiento,
    String? notas,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/gastos/$gastoId',
      cuerpo: {
        'nombre': ?nombre,
        if (categoria != null) 'categoria': categoria.codigo,
        'monto': ?monto,
        'diaVencimiento': ?diaVencimiento,
        'notas': ?notas,
      },
    );
    return Gasto.deJson(datos);
  }

  Future<Gasto> marcarPagado(String gastoId, {DateTime? fecha}) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/gastos/$gastoId/pagar',
      cuerpo: {if (fecha != null) 'fecha': _soloFecha(fecha)},
    );
    return Gasto.deJson(datos);
  }

  Future<Gasto> marcarPendiente(String gastoId) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/gastos/$gastoId/pendiente',
    );
    return Gasto.deJson(datos);
  }

  Future<Gasto> abonar(
    String gastoId,
    double importe, {
    DateTime? fecha,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/gastos/$gastoId/abonar',
      cuerpo: {
        'importe': importe,
        if (fecha != null) 'fecha': _soloFecha(fecha),
      },
    );
    return Gasto.deJson(datos);
  }

  Future<void> eliminarGasto(String gastoId) =>
      _api.eliminar('/api/gastos/$gastoId');

  /// La API espera fechas de negocio sin hora ni zona: `2026-08-17`.
  static String _soloFecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
