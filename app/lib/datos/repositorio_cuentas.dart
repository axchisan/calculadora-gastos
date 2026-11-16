import '../dominio/cuentas_y_sueldo.dart';
import 'cliente_api.dart';

/// Cuentas con su saldo real e ingresos en otra moneda.
class RepositorioCuentas {
  const RepositorioCuentas(this._api);

  final ClienteApi _api;

  Future<List<Cuenta>> listar() async {
    final datos = await _api.obtener<List<dynamic>>('/api/cuentas');
    return datos.map((e) => Cuenta.deJson(e as Map<String, dynamic>)).toList();
  }

  Future<Cuenta> crear({
    required String nombre,
    required TipoCuenta tipo,
    required double saldo,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/cuentas',
      cuerpo: {'nombre': nombre, 'tipo': tipo.codigo, 'saldo': saldo},
    );
    return Cuenta.deJson(datos);
  }

  /// Anota el saldo de hoy, o cambia el nombre o el tipo.
  Future<Cuenta> actualizar(
    String id, {
    String? nombre,
    TipoCuenta? tipo,
    double? saldo,
    bool? activa,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/cuentas/$id',
      cuerpo: {
        'nombre': ?nombre,
        if (tipo != null) 'tipo': tipo.codigo,
        'saldo': ?saldo,
        'activa': ?activa,
      },
    );
    return Cuenta.deJson(datos);
  }

  Future<void> eliminar(String id) => _api.eliminar('/api/cuentas/$id');

  // --- ingresos en otra moneda ---

  Future<List<FuenteIngreso>> fuentes() async {
    final datos = await _api.obtener<List<dynamic>>('/api/sueldo');
    return datos
        .map((e) => FuenteIngreso.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FuenteIngreso> crearFuente({
    required String nombre,
    required double montoMensual,
    required DateTime fechaInicio,
    required MedioCobro medio,
    required double trm,
    String? cuentaDestino,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/sueldo',
      cuerpo: {
        'nombre': nombre,
        'montoMensual': montoMensual,
        'fechaInicio': _fecha(fechaInicio),
        'medio': medio.codigo,
        'trm': trm,
        'cuentaDestino': ?cuentaDestino,
      },
    );
    return FuenteIngreso.deJson(datos);
  }

  Future<FuenteIngreso> actualizarFuente(
    String id, {
    double? montoMensual,
    MedioCobro? medio,
    double? trm,
    String? cuentaDestino,
    int? diasHabilesPago,
    int? diasTolerancia,
    double? comisionPorcentaje,
    double? comisionFija,
    double? descuentoCambioPorcentaje,
    double? costoRetiro,
    DateTime? fechaFin,
    bool quitarFechaFin = false,
    bool? trmAutomatica,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/sueldo/$id',
      cuerpo: {
        'montoMensual': ?montoMensual,
        if (medio != null) 'medio': medio.codigo,
        'trm': ?trm,
        if (trm != null) 'trmFecha': _fecha(DateTime.now()),
        'cuentaDestino': ?cuentaDestino,
        'diasHabilesPago': ?diasHabilesPago,
        'diasTolerancia': ?diasTolerancia,
        'comisionPorcentaje': ?comisionPorcentaje,
        'comisionFija': ?comisionFija,
        'descuentoCambioPorcentaje': ?descuentoCambioPorcentaje,
        'costoRetiro': ?costoRetiro,
        if (fechaFin != null) 'fechaFin': _fecha(fechaFin),
        if (quitarFechaFin) 'quitarFechaFin': true,
        'trmAutomatica': ?trmAutomatica,
      },
    );
    return FuenteIngreso.deJson(datos);
  }

  Future<List<PagoProyectado>> proyeccion(String id, {int pagos = 6}) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/sueldo/$id/proyeccion',
      parametros: {'pagos': pagos},
    );
    return datos
        .map((e) => PagoProyectado.deJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Anota lo que de verdad llegó de un pago; el servidor lo pone como sueldo de su mes.
  Future<PagoRecibido> registrarPago(
    String id, {
    required DateTime mesDePago,
    required double montoPesos,
    required DateTime fecha,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/sueldo/$id/pagos',
      cuerpo: {
        'mesDePago':
            '${mesDePago.year.toString().padLeft(4, '0')}-'
            '${mesDePago.month.toString().padLeft(2, '0')}',
        'montoPesos': montoPesos,
        'fecha': _fecha(fecha),
      },
    );
    return PagoRecibido.deJson(datos);
  }

  /// Pone cada pago proyectado como sueldo base de su mes. Devuelve cuántos meses tocó.
  Future<int> llevarAlPresupuesto(String id, {int pagos = 3}) async {
    final datos = await _api.publicar<List<dynamic>>(
      '/api/sueldo/$id/llevar-al-presupuesto?pagos=$pagos',
    );
    return datos.length;
  }

  static String _fecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
