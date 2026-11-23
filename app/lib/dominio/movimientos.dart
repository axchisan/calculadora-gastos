import 'modelos.dart';

/// De dónde sale cada movimiento: decide qué se puede hacer con él.
enum TipoMovimiento {
  sueldo('SUELDO'),
  ingreso('INGRESO'),
  gasto('GASTO'),
  compra('COMPRA'),
  abono('ABONO'),
  cuota('CUOTA'),
  ahorro('AHORRO'),
  tarjeta('TARJETA');

  const TipoMovimiento(this.codigo);

  final String codigo;

  static TipoMovimiento desde(String codigo) => values.firstWhere(
    (t) => t.codigo == codigo,
    orElse: () => TipoMovimiento.compra,
  );
}

/// Una línea de la lista de movimientos, tal como la arma `GET /api/meses/{id}/movimientos`.
class Movimiento {
  const Movimiento({
    required this.tipo,
    required this.id,
    required this.fecha,
    required this.titulo,
    required this.categoria,
    required this.monto,
    required this.cuenta,
    this.etiqueta,
    this.detalle,
    this.notas,
    this.pendiente = false,
  });

  final TipoMovimiento tipo;
  final String? id;
  final DateTime fecha;
  final String titulo;

  /// Código de la categoría del gasto o la compra, o del tipo del ingreso.
  final String categoria;

  /// Positivo si entra, negativo si sale.
  final double monto;

  /// Si suma al disponible del mes; una compra a crédito sale después.
  final bool cuenta;

  /// `FIJO`, `PRESTAMO` o `CREDITO`.
  final String? etiqueta;
  final String? detalle;
  final String? notas;

  /// Apuntado sin conexión y aún no enviado.
  final bool pendiente;

  bool get entra => monto > 0;

  /// La categoría de gasto, si lo es.
  CategoriaGasto? get categoriaGasto => switch (tipo) {
    TipoMovimiento.gasto ||
    TipoMovimiento.compra => CategoriaGasto.desde(categoria),
    TipoMovimiento.abono ||
    TipoMovimiento.cuota ||
    TipoMovimiento.tarjeta => CategoriaGasto.deuda,
    TipoMovimiento.ahorro => CategoriaGasto.ahorro,
    _ => null,
  };

  /// El tipo de ingreso, si lo es.
  TipoIngreso? get tipoIngreso =>
      tipo == TipoMovimiento.ingreso ? TipoIngreso.desde(categoria) : null;

  /// Nombre legible de la categoría o del tipo.
  String get etiquetaCategoria => switch (tipo) {
    TipoMovimiento.sueldo => 'Sueldo',
    TipoMovimiento.ingreso => tipoIngreso!.etiqueta,
    TipoMovimiento.cuota => 'Crédito',
    TipoMovimiento.tarjeta => 'Tarjeta',
    _ => categoriaGasto?.etiqueta ?? '',
  };

  static Movimiento deJson(Map<String, dynamic> j) => Movimiento(
    tipo: TipoMovimiento.desde(j['tipo'] as String),
    id: j['id'] as String?,
    fecha: DateTime.parse(j['fecha'] as String),
    titulo: j['titulo'] as String,
    categoria: j['categoria'] as String? ?? 'OTRO',
    monto: (j['monto'] as num).toDouble(),
    cuenta: j['cuenta'] as bool? ?? true,
    etiqueta: j['etiqueta'] as String?,
    detalle: j['detalle'] as String?,
    notas: j['notas'] as String?,
    pendiente: j['_pendiente'] == true,
  );
}

/// Un gasto del mes con algo por pagar.
class PorPagar {
  const PorPagar({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.monto,
    required this.pendiente,
    this.vence,
    this.fijo = false,
    this.enCola = false,
  });

  final String id;
  final String nombre;
  final CategoriaGasto categoria;
  final double monto;
  final double pendiente;
  final DateTime? vence;
  final bool fijo;

  /// Apuntado sin conexión y aún no enviado.
  final bool enCola;

  static PorPagar deJson(Map<String, dynamic> j) => PorPagar(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    categoria: CategoriaGasto.desde(j['categoria'] as String? ?? 'OTRO'),
    monto: (j['monto'] as num).toDouble(),
    pendiente: (j['pendiente'] as num).toDouble(),
    vence: j['vence'] == null ? null : DateTime.parse(j['vence'] as String),
    fijo: j['fijo'] as bool? ?? false,
    enCola: j['_pendiente'] == true,
  );
}

/// Un día de la lista: sus movimientos y lo que dejó en neto.
class DiaDeMovimientos {
  const DiaDeMovimientos(this.fecha, this.movimientos);

  final DateTime fecha;
  final List<Movimiento> movimientos;

  /// Solo lo que cuenta en el mes: una compra a crédito no sale hoy.
  double get neto =>
      movimientos.where((m) => m.cuenta).fold(0, (suma, m) => suma + m.monto);
}

/// Qué movimientos se ven.
enum FiltroMovimientos { todo, entradas, salidas }

/// Todo lo del mes para la pantalla de Movimientos.
class MovimientosDelMes {
  const MovimientosDelMes({
    required this.mesId,
    required this.periodo,
    required this.cerrado,
    required this.entro,
    required this.salio,
    required this.queda,
    required this.porPagar,
    required this.movimientos,
  });

  final String mesId;
  final DateTime periodo;
  final bool cerrado;
  final double entro;
  final double salio;
  final double queda;
  final List<PorPagar> porPagar;

  /// Del más reciente al más antiguo.
  final List<Movimiento> movimientos;

  /// Agrupados por día, aplicando el filtro y la búsqueda.
  List<DiaDeMovimientos> porDia({
    FiltroMovimientos filtro = FiltroMovimientos.todo,
    String busqueda = '',
  }) {
    final texto = _normalizar(busqueda.trim());
    final visibles = movimientos.where((m) {
      final pasaFiltro = switch (filtro) {
        FiltroMovimientos.todo => true,
        FiltroMovimientos.entradas => m.entra,
        FiltroMovimientos.salidas => !m.entra,
      };
      if (!pasaFiltro) return false;
      if (texto.isEmpty) return true;
      return _normalizar(
        '${m.titulo} ${m.etiquetaCategoria} ${m.notas ?? ''} ${m.detalle ?? ''}',
      ).contains(texto);
    });

    final dias = <DiaDeMovimientos>[];
    for (final m in visibles) {
      final dia = DateTime(m.fecha.year, m.fecha.month, m.fecha.day);
      if (dias.isNotEmpty && dias.last.fecha == dia) {
        dias.last.movimientos.add(m);
      } else {
        dias.add(DiaDeMovimientos(dia, [m]));
      }
    }
    return dias;
  }

  /// Sin tildes ni mayúsculas, para que «cafe» encuentre «Café».
  static String _normalizar(String texto) {
    const conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sinTilde = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final r in texto.runes) {
      final c = String.fromCharCode(r);
      final i = conTilde.indexOf(c);
      b.write(i >= 0 ? sinTilde[i] : c);
    }
    return b.toString().toLowerCase();
  }

  static MovimientosDelMes deJson(Map<String, dynamic> j) {
    final partes = (j['periodo'] as String).split('-');
    final lista = (j['movimientos'] as List<dynamic>)
        .map((e) => Movimiento.deJson(e as Map<String, dynamic>))
        .toList();
    // Lo apuntado sin conexión llega al principio de la lista: se reordena por fecha. Con el
    // índice como desempate, porque `sort` no es estable y el servidor ya ordenó cada día.
    final orden = {for (var i = 0; i < lista.length; i++) lista[i]: i};
    lista.sort((a, b) {
      final porFecha = b.fecha.compareTo(a.fecha);
      return porFecha != 0 ? porFecha : orden[a]!.compareTo(orden[b]!);
    });
    return MovimientosDelMes(
      mesId: j['mesId'] as String,
      periodo: DateTime(int.parse(partes[0]), int.parse(partes[1])),
      cerrado: j['cerrado'] as bool? ?? false,
      entro: (j['entro'] as num).toDouble(),
      salio: (j['salio'] as num).toDouble(),
      queda: (j['queda'] as num).toDouble(),
      porPagar: (j['porPagar'] as List<dynamic>)
          .map((e) => PorPagar.deJson(e as Map<String, dynamic>))
          .toList(),
      movimientos: lista,
    );
  }
}
