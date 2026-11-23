import 'modelos.dart';
import 'movimientos.dart';

/// Lo gastado en una categoría.
class GastoCategoria {
  const GastoCategoria(this.categoria, this.total);

  final CategoriaGasto categoria;
  final double total;
}

/// Entró y salió en un mes. Los estimados son del mes que viene: sueldo esperado y pagos ya
/// programados, no lo que de verdad pasó.
class BarraMes {
  const BarraMes({
    required this.mes,
    required this.entro,
    required this.salio,
    this.estimado = false,
  });

  final DateTime mes;
  final double entro;
  final double salio;
  final bool estimado;
}

/// Lo que responde Análisis: en qué se fue el dinero del mes, cuánto se fue en deudas y cómo
/// van los meses.
class AnalisisDelMes {
  AnalisisDelMes(this.movimientos);

  final MovimientosDelMes movimientos;

  bool _esPagoDeDeuda(Movimiento m) =>
      !m.entra &&
      (m.tipo == TipoMovimiento.abono ||
          m.tipo == TipoMovimiento.cuota ||
          m.tipo == TipoMovimiento.tarjeta ||
          ((m.tipo == TipoMovimiento.gasto ||
                  m.tipo == TipoMovimiento.compra) &&
              m.categoriaGasto == CategoriaGasto.deuda));

  /// Lo gastado de verdad (gastos pagados y compras, también las de crédito), sin pagos de
  /// deudas ni ahorro. Responde a «¿en qué se me va el dinero?», y ahí una cuota de un crédito
  /// no dice nada de cómo se gasta.
  late final List<GastoCategoria> porCategoria = () {
    final sumas = <CategoriaGasto, double>{};
    for (final m in movimientos.movimientos) {
      if (m.entra || _esPagoDeDeuda(m)) continue;
      if (m.tipo != TipoMovimiento.gasto && m.tipo != TipoMovimiento.compra) {
        continue;
      }
      final c = m.categoriaGasto;
      if (c == null || c == CategoriaGasto.ahorro) continue;
      sumas.update(c, (v) => v + m.monto.abs(), ifAbsent: () => m.monto.abs());
    }
    final lista = [
      for (final e in sumas.entries)
        if (e.value > 0) GastoCategoria(e.key, e.value),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return lista;
  }();

  double get totalGastado => porCategoria.fold(0, (s, c) => s + c.total);

  /// Lo que se fue en pagar deudas, cuotas de créditos y tarjetas.
  double get pagadoEnDeudas => movimientos.movimientos
      .where(_esPagoDeDeuda)
      .fold(0, (s, m) => s + m.monto.abs());

  double totalDe(CategoriaGasto c) => porCategoria
      .where((g) => g.categoria == c)
      .fold(0, (s, g) => s + g.total);

  /// Frases cortas con lo importante, en el orden en que conviene leerlas.
  List<FraseAnalisis> get frases {
    final frases = <FraseAnalisis>[];
    if (porCategoria.isNotEmpty) {
      final primera = porCategoria.first;
      final parte = totalGastado == 0 ? 0 : primera.total / totalGastado;
      frases.add(
        FraseAnalisis(
          FraseTipo.categoria,
          primera.categoria,
          'Lo que más se llevó fue ',
          primera.categoria.etiqueta.toLowerCase(),
          parte >= 0.25
              ? ': ${(parte * 100).round()} % de lo que gastaste.'
              : '.',
          primera.total,
        ),
      );
    }
    final mascota = totalDe(CategoriaGasto.mascota);
    if (mascota > 0) {
      frases.add(
        FraseAnalisis(
          FraseTipo.categoria,
          CategoriaGasto.mascota,
          'En tu mascota se fueron ',
          null,
          '.',
          mascota,
        ),
      );
    }
    final suscripciones = totalDe(CategoriaGasto.suscripciones);
    if (suscripciones > 0) {
      frases.add(
        FraseAnalisis(
          FraseTipo.categoria,
          CategoriaGasto.suscripciones,
          'Tus suscripciones suman ',
          null,
          ' este mes.',
          suscripciones,
        ),
      );
    }
    final deudas = pagadoEnDeudas;
    if (deudas > 0) {
      frases.add(
        FraseAnalisis(
          FraseTipo.deudas,
          CategoriaGasto.deuda,
          'Además pagaste ',
          null,
          ' de deudas y cuotas.',
          deudas,
        ),
      );
    }
    return frases;
  }

  /// Los últimos meses, hasta el actual, y el siguiente como estimado si ya existe.
  static List<BarraMes> mesAMes(
    List<ResumenMensual> serie,
    DateTime actual, {
    int meses = 6,
  }) {
    final hoy = DateTime(actual.year, actual.month);
    final siguiente = DateTime(actual.year, actual.month + 1);
    final reales = <BarraMes>[];
    BarraMes? estimado;
    for (final r in serie) {
      final mes = DateTime(r.periodo.year, r.periodo.month);
      if (!mes.isAfter(hoy)) {
        reales.add(
          BarraMes(
            mes: mes,
            entro: r.ingresoTotal,
            salio: r.ingresoTotal - r.disponibleHoy,
          ),
        );
      } else if (mes == siguiente) {
        estimado = BarraMes(
          mes: mes,
          entro: r.ingresoProyectado,
          salio: r.comprometidoConCuotas,
          estimado: true,
        );
      }
    }
    reales.sort((a, b) => a.mes.compareTo(b.mes));
    // Los meses del principio sin ninguna salida son de antes de empezar a apuntar gastos (solo
    // tienen el sueldo puesto): enseñarlos haría creer que ese mes no se gastó nada.
    while (reales.length > 1 && reales.first.salio <= 0) {
      reales.removeAt(0);
    }
    final ultimos = reales.length > meses
        ? reales.sublist(reales.length - meses)
        : reales;
    return [...ultimos, ?estimado];
  }
}

enum FraseTipo { categoria, deudas }

/// «Tus suscripciones suman $62.700 este mes.»: un texto antes, la cifra en negrita y uno
/// después. [destacado] va en negrita antes de la cifra si existe.
class FraseAnalisis {
  const FraseAnalisis(
    this.tipo,
    this.categoria,
    this.antes,
    this.destacado,
    this.despues,
    this.monto,
  );

  final FraseTipo tipo;
  final CategoriaGasto categoria;
  final String antes;
  final String? destacado;
  final String despues;
  final double monto;
}
