/// Créditos con cuadro de amortización.
///
/// Se separan de las deudas porque no son lo mismo: una deuda es una cifra que se va abonando,
/// y un crédito es un plan cerrado donde cada cuota reparte entre capital e interés. Ese reparto
/// es lo que permite saber cuánto se ahorra adelantando dinero.
library;

/// Qué se hace con lo que se ahorra al abonar de más.
enum ModoDeAbono {
  /// Se mantienen las cuotas que quedan y baja el importe de cada una.
  reducirCuota('REDUCIR_CUOTA', 'Bajar la cuota'),

  /// Se mantiene el importe y el crédito se termina antes.
  reducirPlazo('REDUCIR_PLAZO', 'Terminar antes');

  const ModoDeAbono(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;
}

/// Una cuota del cuadro, con los mismos conceptos que imprime el banco.
class CuotaCredito {
  const CuotaCredito({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.saldoCapital,
    required this.capital,
    required this.interes,
    required this.cargos,
    required this.valorCuota,
    required this.pagada,
    this.fechaPago,
    this.montoPagado,
  });

  final String id;
  final int numero;
  final DateTime fecha;

  /// Lo que se debe justo antes de pagar esta cuota.
  final double saldoCapital;

  final double capital;
  final double interes;

  /// Todo lo que no es capital ni interés: seguro, Mipyme, mora.
  final double cargos;

  final double valorCuota;
  final bool pagada;
  final DateTime? fechaPago;
  final double? montoPagado;

  /// Qué parte de la cuota mata deuda de verdad.
  ///
  /// Al principio del plan es una minoría, y es lo que explica que la deuda baje tan despacio
  /// aunque se pague religiosamente todos los meses.
  double get proporcionCapital =>
      valorCuota == 0 ? 0 : (capital / valorCuota).clamp(0.0, 1.0);

  bool estaVencida(DateTime hoy) => !pagada && fecha.isBefore(hoy);

  static CuotaCredito deJson(Map<String, dynamic> j) => CuotaCredito(
    id: j['id'] as String,
    numero: (j['numero'] as num).toInt(),
    fecha: DateTime.parse(j['fecha'] as String),
    saldoCapital: (j['saldoCapital'] as num).toDouble(),
    capital: (j['capital'] as num).toDouble(),
    interes: (j['interes'] as num).toDouble(),
    cargos: (j['cargos'] as num?)?.toDouble() ?? 0,
    valorCuota: (j['valorCuota'] as num).toDouble(),
    pagada: j['pagada'] as bool,
    fechaPago: j['fechaPago'] == null
        ? null
        : DateTime.parse(j['fechaPago'] as String),
    montoPagado: (j['montoPagado'] as num?)?.toDouble(),
  );
}

/// Un crédito con su estado actual.
class Credito {
  const Credito({
    required this.id,
    required this.entidad,
    required this.montoOriginal,
    required this.plazoCuotas,
    required this.activo,
    required this.cuotasTotales,
    required this.cuotasPagadas,
    required this.cuotasVencidas,
    required this.saldo,
    required this.capitalPagado,
    required this.interesPagado,
    required this.totalPagado,
    required this.capitalPendiente,
    required this.interesPendiente,
    required this.totalPendiente,
    required this.costeTotal,
    required this.porcentajePagado,
    this.numeroOperacion,
    this.descripcion,
    this.tasaEa,
    this.diaPago,
    this.fechaVencimiento,
    this.proximaCuota,
  });

  final String id;
  final String entidad;
  final String? numeroOperacion;
  final String? descripcion;
  final double montoOriginal;

  /// Tasa efectiva anual en porcentaje, tal y como la publica el banco.
  final double? tasaEa;

  final int plazoCuotas;
  final int? diaPago;
  final DateTime? fechaVencimiento;
  final bool activo;

  final int cuotasTotales;
  final int cuotasPagadas;
  final int cuotasVencidas;

  /// Capital que se debe hoy.
  final double saldo;

  final double capitalPagado;
  final double interesPagado;
  final double totalPagado;
  final double capitalPendiente;
  final double interesPendiente;
  final double totalPendiente;

  /// Lo que el crédito cuesta por encima de lo prestado.
  final double costeTotal;

  final double porcentajePagado;
  final CuotaCredito? proximaCuota;

  int get cuotasRestantes => cuotasTotales - cuotasPagadas;
  bool get estaSaldado => cuotasRestantes == 0;
  bool get tieneVencidas => cuotasVencidas > 0;

  /// Lo que se devuelve por cada peso prestado.
  ///
  /// Es la cifra que no aparece en ningún extracto: al 76% anual se devuelve más de una vez y
  /// media lo recibido.
  double get vecesLoPrestado =>
      montoOriginal == 0 ? 0 : (montoOriginal + costeTotal) / montoOriginal;

  static Credito deJson(Map<String, dynamic> j) => Credito(
    id: j['id'] as String,
    entidad: j['entidad'] as String,
    numeroOperacion: j['numeroOperacion'] as String?,
    descripcion: j['descripcion'] as String?,
    montoOriginal: (j['montoOriginal'] as num).toDouble(),
    tasaEa: (j['tasaEa'] as num?)?.toDouble(),
    plazoCuotas: (j['plazoCuotas'] as num).toInt(),
    diaPago: (j['diaPago'] as num?)?.toInt(),
    fechaVencimiento: j['fechaVencimiento'] == null
        ? null
        : DateTime.parse(j['fechaVencimiento'] as String),
    activo: j['activo'] as bool,
    cuotasTotales: (j['cuotasTotales'] as num).toInt(),
    cuotasPagadas: (j['cuotasPagadas'] as num).toInt(),
    cuotasVencidas: (j['cuotasVencidas'] as num).toInt(),
    saldo: (j['saldo'] as num).toDouble(),
    capitalPagado: (j['capitalPagado'] as num).toDouble(),
    interesPagado: (j['interesPagado'] as num).toDouble(),
    totalPagado: (j['totalPagado'] as num).toDouble(),
    capitalPendiente: (j['capitalPendiente'] as num).toDouble(),
    interesPendiente: (j['interesPendiente'] as num).toDouble(),
    totalPendiente: (j['totalPendiente'] as num).toDouble(),
    costeTotal: (j['costeTotal'] as num).toDouble(),
    porcentajePagado: (j['porcentajePagado'] as num).toDouble(),
    proximaCuota: j['proximaCuota'] == null
        ? null
        : CuotaCredito.deJson(j['proximaCuota'] as Map<String, dynamic>),
  );
}

/// Lo que cambiaría al abonar de más a capital.
class SimulacionAbono {
  const SimulacionAbono({
    required this.abono,
    required this.modo,
    required this.cuotasAntes,
    required this.cuotaAntes,
    required this.interesAntes,
    required this.totalAntes,
    required this.cuotasDespues,
    required this.cuotaDespues,
    required this.interesDespues,
    required this.totalDespues,
    required this.ahorroInteres,
    required this.cuotasAhorradas,
    required this.ahorroNeto,
    required this.rendimiento,
    this.desdeCuando,
  });

  final double abono;
  final ModoDeAbono modo;

  final int cuotasAntes;
  final double cuotaAntes;
  final double interesAntes;
  final double totalAntes;

  final int cuotasDespues;
  final double cuotaDespues;
  final double interesDespues;
  final double totalDespues;

  /// Intereses que ese capital ya no genera.
  final double ahorroInteres;

  /// Cuántas cuotas desaparecen. Cero si se eligió bajar la cuota.
  final int cuotasAhorradas;

  /// Lo que se deja de pagar en total, descontando el propio abono.
  final double ahorroNeto;

  /// Cuánto se ahorra por cada cien pesos adelantados.
  final double rendimiento;

  final DateTime? desdeCuando;

  /// Cuánto baja la cuota mensual.
  double get bajaLaCuota => cuotaAntes - cuotaDespues;

  static SimulacionAbono deJson(Map<String, dynamic> j) => SimulacionAbono(
    abono: (j['abono'] as num).toDouble(),
    modo: ModoDeAbono.values.firstWhere(
      (m) => m.codigo == j['modo'],
      orElse: () => ModoDeAbono.reducirPlazo,
    ),
    cuotasAntes: (j['cuotasAntes'] as num).toInt(),
    cuotaAntes: (j['cuotaAntes'] as num).toDouble(),
    interesAntes: (j['interesAntes'] as num).toDouble(),
    totalAntes: (j['totalAntes'] as num).toDouble(),
    cuotasDespues: (j['cuotasDespues'] as num).toInt(),
    cuotaDespues: (j['cuotaDespues'] as num).toDouble(),
    interesDespues: (j['interesDespues'] as num).toDouble(),
    totalDespues: (j['totalDespues'] as num).toDouble(),
    ahorroInteres: (j['ahorroInteres'] as num).toDouble(),
    cuotasAhorradas: (j['cuotasAhorradas'] as num).toInt(),
    ahorroNeto: (j['ahorroNeto'] as num).toDouble(),
    rendimiento: (j['rendimiento'] as num).toDouble(),
    desdeCuando: j['desdeCuando'] == null
        ? null
        : DateTime.parse(j['desdeCuando'] as String),
  );
}
