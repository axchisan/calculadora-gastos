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

  /// Si hay cuentas anotadas. Sin ellas, la cifra de Inicio es el disponible de la app.
  bool get tieneCuentas => cuentas.any((c) => c.activa);

  /// La cifra protagonista: lo que hay en los bancos y el efectivo o, si no se han anotado,
  /// lo que la app calcula como disponible.
  double get tienesHoy =>
      tieneCuentas ? dineroReal : (resumen?.disponibleHoy ?? 0);

  /// Diferencia entre lo que hay en los bancos y lo que la app calcula. Null si falta alguno
  /// de los dos. Positiva: hay más dinero del que la app cree.
  double? get diferenciaConLaApp {
    final r = resumen;
    if (r == null || !tieneCuentas) return null;
    return dineroReal - r.disponibleHoy;
  }

  /// Menos de mil pesos de diferencia se considera cuadrado: son redondeos y el 4×1000.
  static const double toleranciaCuadre = 1000;

  bool get cuadra {
    final diferencia = diferenciaConLaApp;
    return diferencia != null && diferencia.abs() < toleranciaCuadre;
  }

  /// Último día del mes presupuestal en curso: el 27 del mes que le da nombre.
  DateTime get finDelMes => DateTime(periodo.year, periodo.month, 27);

  /// Primer día del mes presupuestal en curso: el 28 del mes anterior.
  DateTime get inicioDelMes => DateTime(periodo.year, periodo.month - 1, 28);

  int get diasParaCerrar => _dia(finDelMes).difference(_dia(hoy)).inDays;

  /// Lo vencido sin pagar.
  List<ProximoPago> get vencidos =>
      proximosPagos.where((p) => p.vencido && !p.ingreso).toList();

  /// Lo que falta pagar de este mes: gastos sin día fijo o que vencen antes de cerrarlo.
  List<ProximoPago> get pendientesDelMes => proximosPagos
      .where(
        (p) =>
            !p.ingreso &&
            !p.vencido &&
            p.tipo == TipoProximoPago.gasto &&
            (p.fecha == null || !p.fecha!.isAfter(finDelMes)),
      )
      .toList();

  /// El próximo sueldo que se espera, si hay alguno en el horizonte.
  ProximoPago? get proximoSueldo =>
      proximosPagos.where((p) => p.ingreso).firstOrNull;

  /// Lo que quedaría después de pagar todo lo que vence antes de que llegue el sueldo (o
  /// antes de cerrar el mes, si no hay sueldo a la vista). Negativo: no alcanza.
  double get quedaHastaElSueldo {
    final limite =
        proximoSueldo?.fecha ?? finDelMes.add(const Duration(days: 1));
    final porPagar = proximosPagos
        .where(
          (p) => !p.ingreso && (p.fecha == null || p.fecha!.isBefore(limite)),
        )
        .fold<double>(0, (suma, p) => suma + p.monto);
    return tienesHoy - porPagar;
  }

  /// Días en los que vencen dos pagos o más, con lo que se paga ese día.
  Map<DateTime, List<ProximoPago>> get pagosJuntos {
    final porDia = <DateTime, List<ProximoPago>>{};
    for (final p in proximosPagos) {
      if (p.ingreso || p.fecha == null) continue;
      porDia.putIfAbsent(_dia(p.fecha!), () => []).add(p);
    }
    return Map.fromEntries(porDia.entries.where((e) => e.value.length > 1));
  }

  static DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

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
