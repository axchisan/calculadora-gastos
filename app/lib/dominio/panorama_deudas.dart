/// De dónde sale una deuda del panorama: decide qué detalle se abre.
enum OrigenDeuda { credito, deuda }

/// Una deuda viva, sea un crédito con cuadro o una deuda (tarjeta, préstamo, familia).
class ParteDeuda {
  const ParteDeuda({
    required this.origen,
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.saldo,
    required this.progreso,
    required this.sinPlan,
    this.terminaEn,
    this.proximoPago,
    this.proximoMonto,
    this.cuotas,
  });

  final OrigenDeuda origen;
  final String id;
  final String nombre;

  /// `CREDITO` o el tipo de la deuda: `TARJETA_CREDITO`, `PRESTAMO_BANCARIO`…
  final String tipo;
  final double saldo;

  /// Qué parte se lleva pagada, de 0 a 1.
  final double progreso;

  /// Sin cuota ni fecha, o con una cuota que no alcanza: no se sabe cuándo termina.
  final bool sinPlan;

  /// Mes del último pago si se pagan solo las cuotas (día uno).
  final DateTime? terminaEn;
  final DateTime? proximoPago;
  final double? proximoMonto;

  /// «Cuota 4 de 18», en los créditos.
  final String? cuotas;

  String get etiquetaTipo => switch (tipo) {
    'CREDITO' => 'Crédito',
    'TARJETA_CREDITO' => 'Tarjeta',
    'PRESTAMO_BANCARIO' => 'Préstamo',
    'FAMILIAR' => 'Familia',
    'AMIGO' => 'Amigo',
    _ => 'Deuda',
  };

  static ParteDeuda deJson(Map<String, dynamic> j) => ParteDeuda(
    origen: j['origen'] == 'CREDITO' ? OrigenDeuda.credito : OrigenDeuda.deuda,
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    tipo: j['tipo'] as String? ?? 'OTRO',
    saldo: (j['saldo'] as num).toDouble(),
    progreso: (j['progreso'] as num? ?? 0).toDouble(),
    sinPlan: j['sinPlan'] as bool? ?? false,
    terminaEn: _mes(j['terminaEn'] as String?),
    proximoPago: j['proximoPago'] == null
        ? null
        : DateTime.parse(j['proximoPago'] as String),
    proximoMonto: (j['proximoMonto'] as num?)?.toDouble(),
    cuotas: j['cuotas'] as String?,
  );
}

/// Lo que se deberá al empezar un mes. El primero es hoy.
class PuntoDeuda {
  const PuntoDeuda(this.mes, this.total);

  final DateTime mes;
  final double total;
}

/// Lo que otra persona le debe al usuario.
class TeDeben {
  const TeDeben({
    required this.id,
    required this.nombre,
    required this.saldo,
    this.descripcion,
    this.desde,
  });

  final String id;
  final String nombre;
  final double saldo;
  final String? descripcion;
  final DateTime? desde;

  static TeDeben deJson(Map<String, dynamic> j) => TeDeben(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    saldo: (j['saldo'] as num).toDouble(),
    descripcion: j['descripcion'] as String?,
    desde: j['desde'] == null ? null : DateTime.parse(j['desde'] as String),
  );
}

class DeudaSaldada {
  const DeudaSaldada(this.origen, this.id, this.nombre);

  final OrigenDeuda origen;
  final String id;
  final String nombre;
}

/// Todo lo que se debe y cómo baja, tal como llega de `GET /api/deudas/panorama`.
class PanoramaDeudas {
  const PanoramaDeudas({
    required this.total,
    required this.partes,
    required this.proyeccion,
    required this.saldadas,
    this.terminaTodoEn,
    this.teDeben = const [],
    this.totalTeDeben = 0,
  });

  final double total;

  /// De la que más se debe a la que menos.
  final List<ParteDeuda> partes;
  final List<PuntoDeuda> proyeccion;
  final List<DeudaSaldada> saldadas;

  /// Null si alguna deuda no tiene forma de terminar.
  final DateTime? terminaTodoEn;

  /// Lo que le deben al usuario; no suma a [total].
  final List<TeDeben> teDeben;
  final double totalTeDeben;

  /// Las que no dejan saber cuándo se termina.
  List<ParteDeuda> get sinPlan => partes.where((p) => p.sinPlan).toList();

  /// Las que tienen fecha de fin, de la primera que termina a la última.
  List<ParteDeuda> get porFin =>
      partes.where((p) => p.terminaEn != null && !p.sinPlan).toList()
        ..sort((a, b) => a.terminaEn!.compareTo(b.terminaEn!));

  static PanoramaDeudas deJson(Map<String, dynamic> j) => PanoramaDeudas(
    total: (j['total'] as num).toDouble(),
    partes: (j['partes'] as List<dynamic>)
        .map((e) => ParteDeuda.deJson(e as Map<String, dynamic>))
        .toList(),
    proyeccion: (j['proyeccion'] as List<dynamic>)
        .map(
          (e) => PuntoDeuda(
            _mes((e as Map<String, dynamic>)['mes'] as String)!,
            (e['total'] as num).toDouble(),
          ),
        )
        .toList(),
    saldadas: (j['saldadas'] as List<dynamic>? ?? const []).map((e) {
      final m = e as Map<String, dynamic>;
      return DeudaSaldada(
        m['origen'] == 'CREDITO' ? OrigenDeuda.credito : OrigenDeuda.deuda,
        m['id'] as String,
        m['nombre'] as String,
      );
    }).toList(),
    terminaTodoEn: _mes(j['terminaTodoEn'] as String?),
    teDeben: (j['teDeben'] as List<dynamic>? ?? const [])
        .map((e) => TeDeben.deJson(e as Map<String, dynamic>))
        .toList(),
    totalTeDeben: (j['totalTeDeben'] as num? ?? 0).toDouble(),
  );
}

/// «2026-11» → 1 de noviembre de 2026.
DateTime? _mes(String? texto) {
  if (texto == null) return null;
  final partes = texto.split('-');
  return DateTime(int.parse(partes[0]), int.parse(partes[1]));
}
