/// «Mi plan»: lo que sobra del sueldo cada mes y cuándo se alcanzan las metas.
library;

DateTime _mes(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]));
}

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Una cuota que vence en el mes.
class PagoPlan {
  const PagoPlan({
    required this.nombre,
    required this.monto,
    required this.fecha,
    required this.esCredito,
  });

  final String nombre;
  final double monto;
  final DateTime fecha;
  final bool esCredito;

  static PagoPlan deJson(Map<String, dynamic> j) => PagoPlan(
    nombre: j['nombre'] as String,
    monto: _n(j['monto']),
    fecha: DateTime.parse(j['fecha'] as String),
    esCredito: j['origen'] == 'CREDITO',
  );
}

class MesPlan {
  const MesPlan({
    required this.periodo,
    required this.actual,
    required this.ingreso,
    required this.ingresoEstimado,
    required this.fijos,
    required this.pagos,
    required this.totalPagos,
    required this.diario,
    required this.sobra,
  });

  /// El mes presupuestal (día 1).
  final DateTime periodo;

  /// El mes en curso: solo cuenta lo que falta hasta el 27.
  final bool actual;
  final double ingreso;
  final bool ingresoEstimado;
  final double fijos;
  final List<PagoPlan> pagos;
  final double totalPagos;
  final double diario;

  /// Lo que queda; negativo si no alcanza.
  final double sobra;

  static MesPlan deJson(Map<String, dynamic> j) => MesPlan(
    periodo: _mes(j['periodo'] as String),
    actual: j['actual'] as bool? ?? false,
    ingreso: _n(j['ingreso']),
    ingresoEstimado: j['ingresoEstimado'] as bool? ?? false,
    fijos: _n(j['fijos']),
    pagos: [
      for (final p in j['pagos'] as List<dynamic>? ?? const [])
        PagoPlan.deJson(p as Map<String, dynamic>),
    ],
    totalPagos: _n(j['totalPagos']),
    diario: _n(j['diario']),
    sobra: _n(j['sobra']),
  );
}

class AportePlan {
  const AportePlan(this.periodo, this.monto, this.acumulado);

  final DateTime periodo;
  final double monto;
  final double acumulado;
}

class MetaPlan {
  const MetaPlan({
    required this.id,
    required this.nombre,
    required this.objetivo,
    required this.ahorrado,
    required this.faltan,
    required this.tipoAsignacion,
    required this.valor,
    required this.aporteMensual,
    required this.aportes,
    this.alcanzaEn,
    this.alcanzaEnConTodo,
  });

  final String id;
  final String nombre;
  final double objetivo;
  final double ahorrado;
  final double faltan;
  final String tipoAsignacion;
  final double valor;
  final double aporteMensual;
  final List<AportePlan> aportes;

  /// Mes en que se completa apartando lo que dice la meta; null si no alcanza en el plan.
  final DateTime? alcanzaEn;

  /// Mes en que se completaría apartando todo lo que sobra.
  final DateTime? alcanzaEnConTodo;

  double get progreso =>
      objetivo <= 0 ? 0 : (ahorrado / objetivo).clamp(0, 1).toDouble();

  static MetaPlan deJson(Map<String, dynamic> j) => MetaPlan(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    objetivo: _n(j['objetivo']),
    ahorrado: _n(j['ahorrado']),
    faltan: _n(j['faltan']),
    tipoAsignacion: j['tipoAsignacion'] as String? ?? 'MONTO_FIJO',
    valor: _n(j['valor']),
    aporteMensual: _n(j['aporteMensual']),
    aportes: [
      for (final a in j['aportes'] as List<dynamic>? ?? const [])
        AportePlan(
          _mes((a as Map<String, dynamic>)['periodo'] as String),
          _n(a['monto']),
          _n(a['acumulado']),
        ),
    ],
    alcanzaEn: j['alcanzaEn'] == null ? null : _mes(j['alcanzaEn'] as String),
    alcanzaEnConTodo: j['alcanzaEnConTodo'] == null
        ? null
        : _mes(j['alcanzaEnConTodo'] as String),
  );
}

class Plan {
  const Plan({
    required this.gastoDiario,
    required this.gastoDiarioEstimado,
    required this.gastoDiarioPropio,
    required this.sobraPromedio,
    required this.meses,
    required this.metas,
  });

  final double gastoDiario;
  final double gastoDiarioEstimado;
  final bool gastoDiarioPropio;

  /// Lo que sobra en promedio en los meses siguientes al actual.
  final double sobraPromedio;
  final List<MesPlan> meses;
  final List<MetaPlan> metas;

  /// El primer mes completo (el siguiente al actual), el que importa para planear.
  MesPlan? get proximo => meses.length > 1 ? meses[1] : null;

  static Plan deJson(Map<String, dynamic> j) => Plan(
    gastoDiario: _n(j['gastoDiario']),
    gastoDiarioEstimado: _n(j['gastoDiarioEstimado']),
    gastoDiarioPropio: j['gastoDiarioPropio'] as bool? ?? false,
    sobraPromedio: _n(j['sobraPromedio']),
    meses: [
      for (final m in j['meses'] as List<dynamic>? ?? const [])
        MesPlan.deJson(m as Map<String, dynamic>),
    ],
    metas: [
      for (final m in j['metas'] as List<dynamic>? ?? const [])
        MetaPlan.deJson(m as Map<String, dynamic>),
    ],
  );
}
