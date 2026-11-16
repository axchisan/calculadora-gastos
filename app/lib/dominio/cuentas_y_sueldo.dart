/// Dónde está guardado el dinero.
enum TipoCuenta {
  banco('BANCO', 'Banco'),
  billetera('BILLETERA', 'Billetera digital'),
  efectivo('EFECTIVO', 'Efectivo');

  const TipoCuenta(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoCuenta desde(String codigo) => TipoCuenta.values.firstWhere(
    (t) => t.codigo == codigo,
    orElse: () => TipoCuenta.banco,
  );
}

/// Un sitio donde hay dinero, con el saldo de la última vez que se miró.
class Cuenta {
  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.saldo,
    required this.saldoAl,
    required this.activa,
  });

  final String id;
  final String nombre;
  final TipoCuenta tipo;
  final double saldo;

  /// Día en que se consultó el saldo.
  final DateTime saldoAl;
  final bool activa;

  /// Días desde la última vez que se anotó el saldo.
  int get diasSinActualizar =>
      DateTime.now().difference(saldoAl).inDays.clamp(0, 9999);

  static Cuenta deJson(Map<String, dynamic> j) => Cuenta(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    tipo: TipoCuenta.desde(j['tipo'] as String),
    saldo: (j['saldo'] as num).toDouble(),
    saldoAl: DateTime.parse(j['saldoAl'] as String),
    activa: j['activa'] as bool,
  );
}

/// Cómo llega a Colombia un ingreso cobrado en otra moneda.
enum MedioCobro {
  transferencia('TRANSFERENCIA', 'Transferencia directa'),
  paypal('PAYPAL', 'PayPal');

  const MedioCobro(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static MedioCobro desde(String codigo) => MedioCobro.values.firstWhere(
    (m) => m.codigo == codigo,
    orElse: () => MedioCobro.transferencia,
  );
}

/// Lo que de verdad llegó de un pago, con la tasa que efectivamente se aplicó.
class PagoRecibido {
  const PagoRecibido({
    required this.mesDePago,
    required this.montoOriginal,
    required this.montoPesos,
    required this.fecha,
    required this.tasaEfectiva,
  });

  final DateTime mesDePago;
  final double montoOriginal;
  final double montoPesos;
  final DateTime fecha;
  final double tasaEfectiva;

  static PagoRecibido deJson(Map<String, dynamic> j) => PagoRecibido(
    mesDePago: PagoProyectado._mes(j['mesDePago'] as String),
    montoOriginal: (j['montoOriginal'] as num).toDouble(),
    montoPesos: (j['montoPesos'] as num).toDouble(),
    fecha: DateTime.parse(j['fecha'] as String),
    tasaEfectiva: (j['tasaEfectiva'] as num).toDouble(),
  );
}

/// Un tramo de un pago: la parte que corresponde a un mes del calendario.
class TramoPago {
  const TramoPago({
    required this.mes,
    required this.dias,
    required this.diasDelMes,
    required this.monto,
  });

  final DateTime mes;
  final int dias;
  final int diasDelMes;
  final double monto;

  bool get completo => dias == diasDelMes;
}

/// Un pago esperado, con el periodo que cubre y lo que llega en pesos.
class PagoProyectado {
  const PagoProyectado({
    required this.mesDePago,
    required this.desde,
    required this.hasta,
    required this.diasCubiertos,
    required this.prorrateado,
    required this.montoOriginal,
    required this.comisiones,
    required this.montoPesos,
    required this.primerDiaPosible,
    required this.fechaLimite,
    required this.fechaTardia,
    required this.mesPresupuestal,
    this.recibido,
  });

  final DateTime mesDePago;
  final DateTime desde;
  final DateTime hasta;
  final int diasCubiertos;
  final bool prorrateado;
  final double montoOriginal;
  final double comisiones;
  final double montoPesos;
  final DateTime primerDiaPosible;
  final DateTime fechaLimite;
  final DateTime fechaTardia;
  final DateTime mesPresupuestal;

  /// Lo que de verdad llegó, si el pago ya se recibió.
  final PagoRecibido? recibido;

  /// Cuánto cambia este pago, en pesos, si el dólar sube o baja un peso.
  double get pesosPorCadaPesoDeTrm => montoOriginal - comisiones;

  /// Divide el periodo cubierto por meses, con lo que vale cada parte.
  ///
  /// Es el mismo prorrateo que hace el servidor: cada mes incompleto vale la parte de sus días
  /// del calendario, y uno completo vale el mensual entero.
  List<TramoPago> tramos(double mensual) {
    final lista = <TramoPago>[];
    var mes = DateTime(desde.year, desde.month);
    final ultimo = DateTime(hasta.year, hasta.month);
    while (!mes.isAfter(ultimo)) {
      final diasDelMes = DateTime(mes.year, mes.month + 1, 0).day;
      final inicio = mes.year == desde.year && mes.month == desde.month
          ? desde.day
          : 1;
      final fin = mes.year == hasta.year && mes.month == hasta.month
          ? hasta.day
          : diasDelMes;
      final dias = fin - inicio + 1;
      lista.add(
        TramoPago(
          mes: mes,
          dias: dias,
          diasDelMes: diasDelMes,
          monto: dias == diasDelMes ? mensual : mensual * dias / diasDelMes,
        ),
      );
      mes = DateTime(mes.year, mes.month + 1);
    }
    return lista;
  }

  static DateTime _mes(String texto) {
    final partes = texto.split('-');
    return DateTime(int.parse(partes[0]), int.parse(partes[1]));
  }

  static PagoProyectado deJson(Map<String, dynamic> j) => PagoProyectado(
    mesDePago: _mes(j['mesDePago'] as String),
    desde: DateTime.parse(j['desde'] as String),
    hasta: DateTime.parse(j['hasta'] as String),
    diasCubiertos: j['diasCubiertos'] as int,
    prorrateado: j['prorrateado'] as bool,
    montoOriginal: (j['montoOriginal'] as num).toDouble(),
    comisiones: (j['comisiones'] as num).toDouble(),
    montoPesos: (j['montoPesos'] as num).toDouble(),
    primerDiaPosible: DateTime.parse(j['primerDiaPosible'] as String),
    fechaLimite: DateTime.parse(j['fechaLimite'] as String),
    fechaTardia: DateTime.parse(j['fechaTardia'] as String),
    mesPresupuestal: _mes(j['mesPresupuestal'] as String),
    recibido: j['recibido'] == null
        ? null
        : PagoRecibido.deJson(j['recibido'] as Map<String, dynamic>),
  );
}

/// Un ingreso recurrente cobrado en otra moneda.
class FuenteIngreso {
  const FuenteIngreso({
    required this.id,
    required this.nombre,
    required this.moneda,
    required this.montoMensual,
    required this.fechaInicio,
    required this.fechaFin,
    required this.medio,
    required this.cuentaDestino,
    required this.diasHabilesPago,
    required this.diasTolerancia,
    required this.trm,
    required this.trmFecha,
    required this.trmAutomatica,
    required this.comisionPorcentaje,
    required this.comisionFija,
    required this.descuentoCambioPorcentaje,
    required this.costoRetiro,
    required this.activo,
    required this.notas,
    required this.proximosPagos,
    required this.recibidos,
  });

  final String id;
  final String nombre;
  final String moneda;
  final double montoMensual;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final MedioCobro medio;
  final String? cuentaDestino;
  final int diasHabilesPago;
  final int diasTolerancia;
  final double trm;
  final DateTime trmFecha;

  /// Si la TRM se toma sola cada día de la publicación oficial.
  final bool trmAutomatica;
  final double comisionPorcentaje;
  final double comisionFija;
  final double descuentoCambioPorcentaje;
  final double costoRetiro;
  final bool activo;
  final String? notas;
  final List<PagoProyectado> proximosPagos;
  final List<PagoRecibido> recibidos;

  /// Lo que llega de un mes completo, en pesos, con los costos del medio actual.
  double get mesCompletoEnPesos {
    final neto = montoMensual * (1 - comisionPorcentaje / 100) - comisionFija;
    final pesos =
        neto * trm * (1 - descuentoCambioPorcentaje / 100) - costoRetiro;
    return pesos < 0 ? 0 : pesos.floorToDouble();
  }

  static FuenteIngreso deJson(Map<String, dynamic> j) => FuenteIngreso(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    moneda: j['moneda'] as String,
    montoMensual: (j['montoMensual'] as num).toDouble(),
    fechaInicio: DateTime.parse(j['fechaInicio'] as String),
    fechaFin: j['fechaFin'] == null
        ? null
        : DateTime.parse(j['fechaFin'] as String),
    medio: MedioCobro.desde(j['medio'] as String),
    cuentaDestino: j['cuentaDestino'] as String?,
    diasHabilesPago: j['diasHabilesPago'] as int,
    diasTolerancia: j['diasTolerancia'] as int,
    trm: (j['trm'] as num).toDouble(),
    trmFecha: DateTime.parse(j['trmFecha'] as String),
    trmAutomatica: j['trmAutomatica'] as bool? ?? false,
    comisionPorcentaje: (j['comisionPorcentaje'] as num).toDouble(),
    comisionFija: (j['comisionFija'] as num).toDouble(),
    descuentoCambioPorcentaje: (j['descuentoCambioPorcentaje'] as num)
        .toDouble(),
    costoRetiro: (j['costoRetiro'] as num).toDouble(),
    activo: j['activo'] as bool,
    notas: j['notas'] as String?,
    proximosPagos: (j['proximosPagos'] as List<dynamic>)
        .map((e) => PagoProyectado.deJson(e as Map<String, dynamic>))
        .toList(),
    recibidos: ((j['recibidos'] as List<dynamic>?) ?? const [])
        .map((e) => PagoRecibido.deJson(e as Map<String, dynamic>))
        .toList(),
  );
}
