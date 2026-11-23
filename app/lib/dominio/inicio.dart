import 'cuentas_y_sueldo.dart';
import 'modelos.dart';

/// De dónde sale un próximo pago: decide a qué pantalla lleva al tocarlo.
enum TipoProximoPago {
  gasto('GASTO'),
  cuotaCredito('CUOTA_CREDITO'),
  deuda('DEUDA'),
  sueldo('SUELDO');

  const TipoProximoPago(this.codigo);

  final String codigo;

  static TipoProximoPago deCodigo(String codigo) => values.firstWhere(
    (t) => t.codigo == codigo,
    // Un tipo nuevo del servidor no debe romper una app sin actualizar.
    orElse: () => TipoProximoPago.gasto,
  );
}

/// Algo que hay que pagar pronto, o un sueldo que va a llegar.
class ProximoPago {
  const ProximoPago({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.detalle,
    required this.fecha,
    required this.fechaHasta,
    required this.monto,
    required this.ingreso,
    required this.vencido,
  });

  final TipoProximoPago tipo;

  /// Del gasto, la cuota, la deuda o la fuente de sueldo.
  final String id;
  final String titulo;
  final String detalle;

  /// Null en un gasto del mes sin día fijo.
  final DateTime? fecha;

  /// Último día en que puede llegar un sueldo; null en lo demás.
  final DateTime? fechaHasta;
  final double monto;
  final bool ingreso;
  final bool vencido;

  static ProximoPago deJson(Map<String, dynamic> j) => ProximoPago(
    tipo: TipoProximoPago.deCodigo(j['tipo'] as String),
    id: j['id'] as String,
    titulo: j['titulo'] as String,
    detalle: j['detalle'] as String? ?? '',
    fecha: j['fecha'] == null ? null : DateTime.parse(j['fecha'] as String),
    fechaHasta: j['fechaHasta'] == null
        ? null
        : DateTime.parse(j['fechaHasta'] as String),
    monto: (j['monto'] as num).toDouble(),
    ingreso: j['ingreso'] as bool? ?? false,
    vencido: j['vencido'] as bool? ?? false,
  );
}

/// Todo lo de la pantalla de Inicio, tal como llega de `GET /api/inicio`.
class DatosInicio {
  const DatosInicio({
    required this.hoy,
    required this.periodo,
    required this.resumen,
    required this.cuentas,
    required this.proximosPagos,
  });

  final DateTime hoy;

  /// Mes presupuestal en curso (día uno del mes que le da nombre).
  final DateTime periodo;

  /// Null si el mes en curso aún no se ha creado.
  final ResumenMensual? resumen;
  final List<Cuenta> cuentas;

  /// Vencido primero, después lo del mes sin día fijo y luego por fecha.
  final List<ProximoPago> proximosPagos;

  /// El dinero que de verdad hay hoy: la suma de las cuentas activas.
  double get dineroReal =>
      cuentas.where((c) => c.activa).fold(0, (suma, c) => suma + c.saldo);

  static DatosInicio deJson(Map<String, dynamic> j) {
    final partes = (j['periodo'] as String).split('-');
    return DatosInicio(
      hoy: DateTime.parse(j['hoy'] as String),
      periodo: DateTime(int.parse(partes[0]), int.parse(partes[1])),
      resumen: j['resumen'] == null
          ? null
          : ResumenMensual.deJson(j['resumen'] as Map<String, dynamic>),
      cuentas: (j['cuentas'] as List<dynamic>)
          .map((e) => Cuenta.deJson(e as Map<String, dynamic>))
          .toList(),
      proximosPagos: (j['proximosPagos'] as List<dynamic>)
          .map((e) => ProximoPago.deJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
