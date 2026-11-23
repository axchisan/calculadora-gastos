import '../dominio/modelos.dart';
import '../dominio/movimientos.dart';
import '../core/identificadores.dart';
import 'cliente_api.dart';
import 'cola_pendientes.dart';

/// Acceso a los meses, sus gastos y el resumen.
///
/// La copia local de las lecturas la gestiona [ClienteApi] para todas las secciones; aquí ya no
/// hace falta un caché propio.
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

  // --- ingresos extra ---

  Future<List<IngresoExtra>> ingresos(String mesId) async {
    final datos = await _api.obtener<List<dynamic>>(
      '/api/meses/$mesId/ingresos',
    );
    return datos
        .map((e) => IngresoExtra.deJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Todo lo que entró y salió en el mes, y lo que falta pagar.
  Future<MovimientosDelMes> movimientos(String mesId) async =>
      MovimientosDelMes.deJson(
        await _api.obtener<Map<String, dynamic>>(
          '/api/meses/$mesId/movimientos',
        ),
      );

  Future<IngresoExtra> crearIngreso(
    String mesId, {
    required String concepto,
    required double monto,
    required DateTime fecha,
    required bool recibido,
    TipoIngreso tipo = TipoIngreso.otro,
    String? notas,
  }) async {
    final id = nuevoIdentificador();
    final dia = _formatear(fecha);
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses/$mesId/ingresos',
      cuerpo: {
        'id': id,
        'concepto': concepto,
        'monto': monto,
        'fecha': dia,
        'recibido': recibido,
        'tipo': tipo.codigo,
        'notas': ?notas,
      },
      descripcion: 'Ingreso · $concepto',
      sinConexion: Superposicion(
        ruta: '/api/meses/$mesId/ingresos',
        datos: {
          'id': id,
          'concepto': concepto,
          'monto': monto,
          'fecha': dia,
          'recibido': recibido,
          'tipo': tipo.codigo,
          'notas': notas,
          '_pendiente': true,
        },
        tambien: [
          if (recibido)
            Superposicion(
              ruta: '/api/meses/$mesId/movimientos',
              campoLista: 'movimientos',
              datos: {
                'tipo': 'INGRESO',
                'id': id,
                'fecha': dia,
                'titulo': concepto,
                'categoria': tipo.codigo,
                'monto': monto,
                'cuenta': true,
                'etiqueta': tipo == TipoIngreso.prestamo ? 'PRESTAMO' : null,
                'notas': notas,
                '_pendiente': true,
              },
            ),
        ],
      ),
    );
    return IngresoExtra.deJson(datos);
  }

  /// Corrige un ingreso: concepto, monto, fecha, tipo o nota.
  Future<IngresoExtra> editarIngreso(
    String ingresoId, {
    String? concepto,
    double? monto,
    DateTime? fecha,
    TipoIngreso? tipo,
    String? notas,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/ingresos/$ingresoId',
      cuerpo: {
        'concepto': ?concepto,
        'monto': ?monto,
        if (fecha != null) 'fecha': _formatear(fecha),
        if (tipo != null) 'tipo': tipo.codigo,
        'notas': ?notas,
      },
    );
    return IngresoExtra.deJson(datos);
  }

  Future<IngresoExtra> marcarIngresoRecibido(
    String ingresoId,
    bool recibido,
  ) async {
    // El endpoint lo espera como parámetro de consulta, no en el cuerpo.
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/ingresos/$ingresoId/recibido?recibido=$recibido',
    );
    return IngresoExtra.deJson(datos);
  }

  Future<void> eliminarIngreso(String ingresoId) =>
      _api.eliminar('/api/meses/ingresos/$ingresoId');

  /// Añade al mes los gastos fijos que le falten.
  ///
  /// Las plantillas se copian al crear el mes, así que una creada después no aparece en los
  /// meses ya existentes. Repetirlo no duplica nada ni pisa importes ajustados a mano.
  Future<List<Gasto>> aplicarPlantillas(String mesId) async {
    final datos = await _api.publicar<List<dynamic>>(
      '/api/meses/$mesId/aplicar-plantillas',
    );
    return datos.map((e) => Gasto.deJson(e as Map<String, dynamic>)).toList();
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
    final id = nuevoIdentificador();
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses/$mesId/gastos',
      cuerpo: {
        'id': id,
        'nombre': nombre,
        'categoria': categoria.codigo,
        'monto': monto,
        'diaVencimiento': ?diaVencimiento,
        'notas': ?notas,
      },
      descripcion: 'Gasto · $nombre',
      sinConexion: Superposicion(
        ruta: '/api/meses/$mesId/gastos',
        datos: {
          'id': id,
          'nombre': nombre,
          'categoria': categoria.codigo,
          'monto': monto,
          'montoPagado': 0,
          'saldoPendiente': monto,
          'estado': 'PENDIENTE',
          'origen': 'MANUAL',
          'editable': true,
          'fechaPago': null,
          'diaVencimiento': diaVencimiento,
          'notas': notas,
          '_pendiente': true,
        },
        tambien: [
          if (monto > 0)
            Superposicion(
              ruta: '/api/meses/$mesId/movimientos',
              campoLista: 'porPagar',
              datos: {
                'id': id,
                'nombre': nombre,
                'categoria': categoria.codigo,
                'monto': monto,
                'pendiente': monto,
                'fijo': false,
                '_pendiente': true,
              },
            ),
        ],
      ),
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

  /// Marca un gasto como pagado del todo.
  ///
  /// Con [actual] y [mesId], si no hay conexión el pago queda en la cola y el gasto se ve pagado
  /// enseguida. Pagar dos veces lo mismo deja el gasto igual, así que reenviarlo no hace daño.
  Future<Gasto> marcarPagado(
    String gastoId, {
    DateTime? fecha,
    Gasto? actual,
    String? mesId,
  }) async {
    final dia = _formatear(fecha ?? DateTime.now());
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/gastos/$gastoId/pagar',
      cuerpo: {'fecha': dia},
      descripcion: 'Pagar · ${actual?.nombre ?? 'gasto'}',
      sinConexion: actual == null || mesId == null
          ? null
          : Superposicion(
              ruta: '/api/meses/$mesId/gastos',
              reemplazaId: gastoId,
              datos: {
                ...actual.aJson(),
                'montoPagado': actual.monto,
                'saldoPendiente': 0,
                'estado': 'PAGADO',
                'fechaPago': dia,
                '_pendiente': true,
              },
              tambien: [
                Superposicion(
                  ruta: '/api/meses/$mesId/movimientos',
                  campoLista: 'porPagar',
                  reemplazaId: gastoId,
                  quitar: true,
                  datos: const {},
                ),
                Superposicion(
                  ruta: '/api/meses/$mesId/movimientos',
                  campoLista: 'movimientos',
                  datos: {
                    'tipo': 'GASTO',
                    'id': gastoId,
                    'fecha': dia,
                    'titulo': actual.nombre,
                    'categoria': actual.categoria.codigo,
                    'monto': -actual.monto,
                    'cuenta': true,
                    '_pendiente': true,
                  },
                ),
              ],
            ),
    );
    return Gasto.deJson(datos);
  }

  Future<Gasto> marcarPendiente(String gastoId) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/gastos/$gastoId/pendiente',
    );
    return Gasto.deJson(datos);
  }

  /// Corrige cuánto se lleva pagado, sustituyendo el valor en lugar de sumarlo.
  ///
  /// Con cero, el gasto vuelve a estar pendiente. Sirve para deshacer un pago apuntado por
  /// error o para ajustar la cifra cuando resultó que no se pagó el total.
  Future<Gasto> corregirPago(
    String gastoId,
    double montoPagado, {
    DateTime? fecha,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/gastos/$gastoId/corregir-pago',
      cuerpo: {'montoPagado': montoPagado, 'fecha': ?_soloFecha(fecha)},
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
  static String? _soloFecha(DateTime? fecha) =>
      fecha == null ? null : _formatear(fecha);

  static String _formatear(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
