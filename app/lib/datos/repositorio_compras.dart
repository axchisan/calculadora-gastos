import '../dominio/modelos.dart';
import 'cliente_api.dart';

/// Las compras del día a día, las tarjetas y sus cortes.
class RepositorioCompras {
  const RepositorioCompras(this._api);

  final ClienteApi _api;

  // --- compras ---

  Future<ComprasDelMes> delMes(String mesId) async {
    final datos = await _api.obtener<Map<String, dynamic>>(
      '/api/meses/$mesId/compras',
    );
    return ComprasDelMes.deJson(datos);
  }

  Future<Compra> registrar(
    String mesId, {
    required String descripcion,
    required double monto,
    required CategoriaGasto categoria,
    DateTime? fecha,
    MedioPago? medio,
    String? tarjetaId,
    String? nota,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses/$mesId/compras',
      cuerpo: {
        'descripcion': descripcion,
        'monto': monto,
        'categoria': categoria.codigo,
        'fecha': ?_fecha(fecha),
        if (medio != null) 'medio': medio.codigo,
        'tarjetaId': ?tarjetaId,
        'nota': ?nota,
      },
    );
    return Compra.deJson(datos);
  }

  /// Modifica una compra.
  ///
  /// Cambiar [medio] o [fecha] recalcula de qué mes sale el dinero, que con crédito puede
  /// desplazarse un mes entero.
  Future<Compra> actualizar(
    String compraId, {
    String? descripcion,
    double? monto,
    CategoriaGasto? categoria,
    DateTime? fecha,
    MedioPago? medio,
    String? tarjetaId,
    String? nota,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/compras/$compraId',
      cuerpo: {
        'descripcion': ?descripcion,
        'monto': ?monto,
        if (categoria != null) 'categoria': categoria.codigo,
        'fecha': ?_fecha(fecha),
        if (medio != null) 'medio': medio.codigo,
        'tarjetaId': ?tarjetaId,
        'nota': ?nota,
      },
    );
    return Compra.deJson(datos);
  }

  Future<void> eliminar(String compraId) =>
      _api.eliminar('/api/compras/$compraId');

  // --- tarjetas ---

  Future<List<Tarjeta>> tarjetas() async {
    final datos = await _api.obtener<List<dynamic>>('/api/tarjetas');
    return datos.map((e) => Tarjeta.deJson(e as Map<String, dynamic>)).toList();
  }

  Future<Tarjeta> crearTarjeta({
    required String nombre,
    required TipoTarjeta tipo,
    int? diaCorte,
    int? diaPago,
    String? color,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/tarjetas',
      cuerpo: {
        'nombre': nombre,
        'tipo': tipo.codigo,
        'diaCorte': ?diaCorte,
        'diaPago': ?diaPago,
        'color': ?color,
      },
    );
    return Tarjeta.deJson(datos);
  }

  Future<Tarjeta> actualizarTarjeta(
    String tarjetaId, {
    String? nombre,
    int? diaCorte,
    int? diaPago,
    String? color,
    bool? activa,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/tarjetas/$tarjetaId',
      cuerpo: {
        'nombre': ?nombre,
        'diaCorte': ?diaCorte,
        'diaPago': ?diaPago,
        'color': ?color,
        'activa': ?activa,
      },
    );
    return Tarjeta.deJson(datos);
  }

  Future<void> eliminarTarjeta(String tarjetaId) =>
      _api.eliminar('/api/tarjetas/$tarjetaId');

  /// Enseña a reconocer la tarjeta en las notificaciones de pago del teléfono.
  Future<void> anadirAlias(
    String tarjetaId, {
    String? apodo,
    String? ultimos4,
  }) => _api.publicar<Map<String, dynamic>>(
    '/api/tarjetas/$tarjetaId/alias',
    cuerpo: {'apodo': ?apodo, 'ultimos4': ?ultimos4},
  );

  Future<void> eliminarAlias(String aliasId) =>
      _api.eliminar('/api/tarjetas/alias/$aliasId');

  // --- cortes ---

  Future<List<CorteTarjeta>> cortes(DateTime periodo) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/cortes/${_periodo(periodo)}',
    );
    return datos
        .map((e) => CorteTarjeta.deJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Marca el corte entero de una tarjeta como pagado, o lo devuelve a pendiente.
  Future<void> saldarCorte(
    String tarjetaId,
    DateTime periodo, {
    required bool pagado,
  }) => _api.reemplazar<void>(
    '/api/cortes/${_periodo(periodo)}/tarjetas/$tarjetaId',
    cuerpo: {'pagado': pagado},
  );

  static String? _fecha(DateTime? fecha) => fecha == null
      ? null
      : '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}';

  static String _periodo(DateTime mes) =>
      '${mes.year.toString().padLeft(4, '0')}-'
      '${mes.month.toString().padLeft(2, '0')}';
}
