import '../dominio/modelos.dart';
import 'cache_local.dart';
import 'cliente_api.dart';

/// Acceso a los meses, sus gastos y el resumen.
///
/// Las lecturas del mes se guardan en el caché local. Si la petición falla por falta de red se
/// devuelve lo último conocido en lugar de un error: mirar cifras de ayer es más útil que una
/// pantalla de fallo, siempre que quede claro que no están al día.
class RepositorioMeses {
  const RepositorioMeses(this._api, this._cache);

  final ClienteApi _api;
  final CacheLocal? _cache;

  /// Indica si los últimos datos servidos vinieron del caché por no haber conexión.
  static bool ultimaLecturaDesdeCache = false;

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
    return _conCache(
      clave: 'resumen.$mesId',
      pedir: () =>
          _api.obtener<Map<String, dynamic>>('/api/meses/$mesId/resumen'),
      construir: (json) => ResumenMensual.deJson(json as Map<String, dynamic>),
    );
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
    return _conCache(
      clave: 'gastos.$mesId',
      pedir: () => _api.obtener<List<dynamic>>('/api/meses/$mesId/gastos'),
      construir: (json) => (json as List<dynamic>)
          .map((e) => Gasto.deJson(e as Map<String, dynamic>))
          .toList(),
    );
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

  /// Pide al servidor y guarda el resultado; si no hay conexión, recurre a lo guardado.
  Future<T> _conCache<T>({
    required String clave,
    required Future<dynamic> Function() pedir,
    required T Function(dynamic json) construir,
  }) async {
    try {
      final json = await pedir();
      await _cache?.guardar(clave, json);
      ultimaLecturaDesdeCache = false;
      return construir(json);
    } on ErrorApi catch (e) {
      // Solo se recurre al caché ante un fallo de red. Un 404 o un 403 son respuestas
      // legítimas del servidor y taparlas con datos viejos ocultaría el problema real.
      final guardado = e.esDeConexion ? _cache?.leer(clave) : null;
      if (guardado == null) rethrow;

      ultimaLecturaDesdeCache = true;
      return construir(guardado.datos);
    }
  }

  /// La API espera fechas de negocio sin hora ni zona: `2026-08-17`.
  static String _soloFecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
