/// Modelos que reflejan lo que devuelve la API.
///
/// Se escriben a mano en lugar de generarlos porque son pocos y estables, y evita añadir un
/// paso de generación de código al ciclo de desarrollo.
library;

// --- catálogos ---

enum CategoriaGasto {
  vivienda('VIVIENDA', 'Vivienda'),
  alimentacion('ALIMENTACION', 'Alimentación'),
  transporte('TRANSPORTE', 'Transporte'),
  servicios('SERVICIOS', 'Servicios'),
  suscripciones('SUSCRIPCIONES', 'Suscripciones'),
  salud('SALUD', 'Salud'),
  educacion('EDUCACION', 'Educación'),
  deporte('DEPORTE', 'Deporte'),
  herramientas('HERRAMIENTAS', 'Herramientas'),
  deuda('DEUDA', 'Deuda'),
  ahorro('AHORRO', 'Ahorro'),
  otro('OTRO', 'Otro');

  const CategoriaGasto(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static CategoriaGasto desde(String codigo) => CategoriaGasto.values
      .firstWhere((c) => c.codigo == codigo, orElse: () => CategoriaGasto.otro);
}

enum EstadoGasto {
  pendiente('PENDIENTE', 'Pendiente'),
  parcial('PARCIAL', 'Abonado en parte'),
  pagado('PAGADO', 'Pagado');

  const EstadoGasto(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static EstadoGasto desde(String codigo) => EstadoGasto.values.firstWhere(
    (e) => e.codigo == codigo,
    orElse: () => EstadoGasto.pendiente,
  );
}

enum OrigenGasto {
  manual('MANUAL'),
  plantilla('PLANTILLA'),
  transporte('TRANSPORTE'),
  deuda('DEUDA');

  const OrigenGasto(this.codigo);

  final String codigo;

  static OrigenGasto desde(String codigo) => OrigenGasto.values.firstWhere(
    (o) => o.codigo == codigo,
    orElse: () => OrigenGasto.manual,
  );
}

enum TipoDia {
  oficina('OFICINA', 'Oficina'),
  remoto('REMOTO', 'Remoto'),
  festivo('FESTIVO', 'Festivo'),
  finDeSemana('FIN_DE_SEMANA', 'Fin de semana'),
  vacaciones('VACACIONES', 'Vacaciones'),
  ausente('AUSENTE', 'Ausente');

  const TipoDia(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoDia desde(String codigo) => TipoDia.values.firstWhere(
    (t) => t.codigo == codigo,
    orElse: () => TipoDia.oficina,
  );

  /// Tipos que el usuario puede asignar a mano. Festivo y fin de semana los pone el calendario.
  static const List<TipoDia> asignables = [
    oficina,
    remoto,
    vacaciones,
    ausente,
  ];
}

enum TipoDeuda {
  tarjetaCredito('TARJETA_CREDITO', 'Tarjeta de crédito'),
  prestamoBancario('PRESTAMO_BANCARIO', 'Préstamo bancario'),
  familiar('FAMILIAR', 'Familiar'),
  amigo('AMIGO', 'Amigo'),
  otro('OTRO', 'Otro');

  const TipoDeuda(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoDeuda desde(String codigo) => TipoDeuda.values.firstWhere(
    (t) => t.codigo == codigo,
    orElse: () => TipoDeuda.otro,
  );
}

enum TipoAsignacion {
  porcentajeIngreso('PORCENTAJE_INGRESO', 'Porcentaje del ingreso'),
  montoFijo('MONTO_FIJO', 'Monto fijo'),
  porcentajeSobrante('PORCENTAJE_SOBRANTE', 'Porcentaje de lo que sobra');

  const TipoAsignacion(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoAsignacion desde(String codigo) =>
      TipoAsignacion.values.firstWhere(
        (t) => t.codigo == codigo,
        orElse: () => TipoAsignacion.montoFijo,
      );
}

// --- entidades ---

class Mes {
  const Mes({
    required this.id,
    required this.anio,
    required this.mes,
    required this.ingresoBase,
    required this.cerrado,
    this.notas,
  });

  final String id;
  final int anio;
  final int mes;
  final double ingresoBase;
  final bool cerrado;
  final String? notas;

  DateTime get periodo => DateTime(anio, mes);

  static Mes deJson(Map<String, dynamic> j) => Mes(
    id: j['id'] as String,
    anio: j['anio'] as int,
    mes: j['mes'] as int,
    ingresoBase: (j['ingresoBase'] as num).toDouble(),
    cerrado: j['cerrado'] as bool,
    notas: j['notas'] as String?,
  );
}

class Gasto {
  const Gasto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.monto,
    required this.montoPagado,
    required this.saldoPendiente,
    required this.estado,
    required this.origen,
    required this.editable,
    this.fechaPago,
    this.diaVencimiento,
    this.notas,
  });

  final String id;
  final String nombre;
  final CategoriaGasto categoria;
  final double monto;
  final double montoPagado;
  final double saldoPendiente;
  final EstadoGasto estado;
  final OrigenGasto origen;

  /// Los gastos de transporte y de deuda los mantiene el sistema y se editan desde su módulo.
  final bool editable;

  final DateTime? fechaPago;
  final int? diaVencimiento;
  final String? notas;

  double get proporcionPagada =>
      monto == 0 ? 1 : (montoPagado / monto).clamp(0, 1);

  static Gasto deJson(Map<String, dynamic> j) => Gasto(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    categoria: CategoriaGasto.desde(j['categoria'] as String),
    monto: (j['monto'] as num).toDouble(),
    montoPagado: (j['montoPagado'] as num).toDouble(),
    saldoPendiente: (j['saldoPendiente'] as num).toDouble(),
    estado: EstadoGasto.desde(j['estado'] as String),
    origen: OrigenGasto.desde(j['origen'] as String),
    editable: j['editable'] as bool,
    fechaPago: j['fechaPago'] == null
        ? null
        : DateTime.parse(j['fechaPago'] as String),
    diaVencimiento: j['diaVencimiento'] as int?,
    notas: j['notas'] as String?,
  );
}

class TotalCategoria {
  const TotalCategoria({
    required this.categoria,
    required this.total,
    required this.porcentaje,
  });

  final CategoriaGasto categoria;
  final double total;
  final double porcentaje;

  static TotalCategoria deJson(Map<String, dynamic> j) => TotalCategoria(
    categoria: CategoriaGasto.desde(j['categoria'] as String),
    total: (j['total'] as num).toDouble(),
    porcentaje: (j['porcentaje'] as num).toDouble(),
  );
}

/// Estado financiero completo de un mes.
class ResumenMensual {
  const ResumenMensual({
    required this.mesId,
    required this.periodo,
    required this.cerrado,
    required this.ingresoBase,
    required this.ingresoTotal,
    required this.ingresoProyectado,
    required this.gastoTotal,
    required this.gastoPagado,
    required this.gastoPendiente,
    required this.abonosDeuda,
    required this.aporteAhorro,
    required this.disponibleHoy,
    required this.saldoProyectado,
    required this.deudaTotal,
    required this.ahorroTotal,
    required this.patrimonioNeto,
    required this.comprometido,
    required this.porcentajeComprometido,
    required this.cuotasDeudaPendientes,
    required this.comprometidoConCuotas,
    required this.deudasSinCuota,
    required this.porCategoria,
  });

  final String mesId;
  final DateTime periodo;
  final bool cerrado;
  final double ingresoBase;

  /// Sueldo más los ingresos extra ya cobrados.
  final double ingresoTotal;

  /// Sueldo más todos los ingresos extra previstos, cobrados o no.
  final double ingresoProyectado;

  final double gastoTotal;
  final double gastoPagado;
  final double gastoPendiente;
  final double abonosDeuda;
  final double aporteAhorro;

  /// Lo que hay ahora mismo, contando solo lo ya pagado.
  final double disponibleHoy;

  /// Lo que quedará al cerrar el mes, asumiendo que se paga todo lo pendiente.
  final double saldoProyectado;

  final double deudaTotal;
  final double ahorroTotal;
  final double patrimonioNeto;

  /// Todo lo que ya tiene destino este mes: gastos, abonos a deudas y aportes al ahorro, se
  /// hayan pagado o no. Es la cifra con la que se planifica un mes que aún no ha empezado,
  /// donde lo pagado es cero y no dice nada.
  final double comprometido;

  /// Qué parte del ingreso previsto ya tiene destino, cuotas de deuda incluidas.
  final double porcentajeComprometido;

  /// Lo que falta abonar este mes según las cuotas pactadas de las deudas.
  final double cuotasDeudaPendientes;

  /// Lo comprometido más las cuotas de deuda aún por pagar. Es la cifra del modo estimación.
  final double comprometidoConCuotas;

  /// Deudas activas sin cuota mensual, que no pueden proyectarse.
  final int deudasSinCuota;

  final List<TotalCategoria> porCategoria;

  bool get cierraEnPositivo => saldoProyectado >= 0;

  /// Indica si los compromisos, cuotas de deuda incluidas, superan lo que se espera ingresar.
  bool get estaSobrecomprometido => comprometidoConCuotas > ingresoProyectado;

  /// Lo que quedaría libre tras atender también las cuotas de deuda del mes.
  double get saldoTrasCuotas => ingresoProyectado - comprometidoConCuotas;

  /// Proporción del ingreso con destino, entre 0 y 1, para las barras de progreso.
  double get proporcionComprometida => ingresoProyectado == 0
      ? 0
      : (comprometidoConCuotas / ingresoProyectado).clamp(0.0, 1.0);

  /// Dinero que ya salió este mes, sea en gastos, abonos a deudas o ahorro.
  ///
  /// La barra de pagos solo cuenta gastos, así que un abono a una deuda reducía el disponible
  /// sin dejar rastro visible de a dónde había ido.
  double get salidaReal => gastoPagado + abonosDeuda + aporteAhorro;

  static ResumenMensual deJson(Map<String, dynamic> j) {
    // El periodo llega como "2026-08"; se completa con el día uno para poder formatearlo.
    final periodo = j['periodo'] as String;
    final partes = periodo.split('-');

    return ResumenMensual(
      mesId: j['mesId'] as String,
      periodo: DateTime(int.parse(partes[0]), int.parse(partes[1])),
      cerrado: j['cerrado'] as bool,
      ingresoBase: (j['ingresoBase'] as num).toDouble(),
      ingresoTotal: (j['ingresoTotal'] as num).toDouble(),
      ingresoProyectado: (j['ingresoProyectado'] as num).toDouble(),
      gastoTotal: (j['gastoTotal'] as num).toDouble(),
      gastoPagado: (j['gastoPagado'] as num).toDouble(),
      gastoPendiente: (j['gastoPendiente'] as num).toDouble(),
      abonosDeuda: (j['abonosDeuda'] as num).toDouble(),
      aporteAhorro: (j['aporteAhorro'] as num).toDouble(),
      disponibleHoy: (j['disponibleHoy'] as num).toDouble(),
      saldoProyectado: (j['saldoProyectado'] as num).toDouble(),
      deudaTotal: (j['deudaTotal'] as num).toDouble(),
      ahorroTotal: (j['ahorroTotal'] as num).toDouble(),
      patrimonioNeto: (j['patrimonioNeto'] as num).toDouble(),
      comprometido: (j['comprometido'] as num).toDouble(),
      porcentajeComprometido: (j['porcentajeComprometido'] as num).toDouble(),
      cuotasDeudaPendientes: (j['cuotasDeudaPendientes'] as num).toDouble(),
      comprometidoConCuotas: (j['comprometidoConCuotas'] as num).toDouble(),
      deudasSinCuota: (j['deudasSinCuota'] as num).toInt(),
      porCategoria: (j['porCategoria'] as List<dynamic>)
          .map((e) => TotalCategoria.deJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DiaTransporte {
  const DiaTransporte({
    required this.id,
    required this.fecha,
    required this.tipo,
    required this.hayKarate,
    required this.pasajes,
    required this.overrideManual,
    required this.confirmado,
    this.nombreFestivo,
    this.nota,
  });

  final String id;
  final DateTime fecha;
  final TipoDia tipo;
  final bool hayKarate;
  final int pasajes;

  /// El usuario fijó los pasajes a mano; los recálculos no lo tocan.
  final bool overrideManual;

  /// El día ya transcurrió y se confirmó lo realmente gastado.
  final bool confirmado;

  final String? nombreFestivo;
  final String? nota;

  static DiaTransporte deJson(Map<String, dynamic> j) => DiaTransporte(
    id: j['id'] as String,
    fecha: DateTime.parse(j['fecha'] as String),
    tipo: TipoDia.desde(j['tipo'] as String),
    hayKarate: j['hayKarate'] as bool,
    pasajes: j['pasajes'] as int,
    overrideManual: j['overrideManual'] as bool,
    confirmado: j['confirmado'] as bool,
    nombreFestivo: j['nombreFestivo'] as String?,
    nota: j['nota'] as String?,
  );
}

class ResumenTransporte {
  const ResumenTransporte({
    required this.totalPasajes,
    required this.costoTotal,
    required this.costoConfirmado,
    required this.costoPendiente,
    required this.diasOficina,
    required this.diasRemotos,
    required this.diasFestivos,
    required this.diasKarate,
    required this.pasajesGastados,
    required this.dias,
  });

  final int totalPasajes;
  final double costoTotal;
  final double costoConfirmado;
  final double costoPendiente;
  final int diasOficina;
  final int diasRemotos;
  final int diasFestivos;
  final int diasKarate;
  final int pasajesGastados;
  final List<DiaTransporte> dias;

  static ResumenTransporte deJson(Map<String, dynamic> j) => ResumenTransporte(
    totalPasajes: j['totalPasajes'] as int,
    costoTotal: (j['costoTotal'] as num).toDouble(),
    costoConfirmado: (j['costoConfirmado'] as num).toDouble(),
    costoPendiente: (j['costoPendiente'] as num).toDouble(),
    diasOficina: j['diasOficina'] as int,
    diasRemotos: j['diasRemotos'] as int,
    diasFestivos: j['diasFestivos'] as int,
    diasKarate: j['diasKarate'] as int,
    pasajesGastados: j['pasajesGastados'] as int,
    dias: (j['dias'] as List<dynamic>)
        .map((e) => DiaTransporte.deJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class Deuda {
  const Deuda({
    required this.id,
    required this.acreedor,
    required this.tipo,
    required this.montoOriginal,
    required this.saldo,
    required this.porcentajePagado,
    required this.activa,
    this.descripcion,
    this.tasaInteresMensual,
    this.interesMensualEstimado,
    this.cuotaSugerida,
    this.fechaLimite,
  });

  final String id;
  final String acreedor;
  final TipoDeuda tipo;
  final double montoOriginal;
  final double saldo;
  final double porcentajePagado;
  final bool activa;
  final String? descripcion;
  final double? tasaInteresMensual;
  final double? interesMensualEstimado;
  final double? cuotaSugerida;
  final DateTime? fechaLimite;

  static Deuda deJson(Map<String, dynamic> j) => Deuda(
    id: j['id'] as String,
    acreedor: j['acreedor'] as String,
    tipo: TipoDeuda.desde(j['tipo'] as String),
    montoOriginal: (j['montoOriginal'] as num).toDouble(),
    saldo: (j['saldo'] as num).toDouble(),
    porcentajePagado: (j['porcentajePagado'] as num).toDouble(),
    activa: j['activa'] as bool,
    descripcion: j['descripcion'] as String?,
    tasaInteresMensual: (j['tasaInteresMensual'] as num?)?.toDouble(),
    interesMensualEstimado: (j['interesMensualEstimado'] as num?)?.toDouble(),
    cuotaSugerida: (j['cuotaSugerida'] as num?)?.toDouble(),
    fechaLimite: j['fechaLimite'] == null
        ? null
        : DateTime.parse(j['fechaLimite'] as String),
  );
}

class MetaAhorro {
  const MetaAhorro({
    required this.id,
    required this.nombre,
    required this.tipoAsignacion,
    required this.valor,
    required this.saldoAcumulado,
    required this.prioridad,
    required this.activa,
    this.metaMonto,
    this.porcentajeAlcanzado,
    this.color,
  });

  final String id;
  final String nombre;
  final TipoAsignacion tipoAsignacion;
  final double valor;
  final double saldoAcumulado;
  final int prioridad;
  final bool activa;
  final double? metaMonto;
  final double? porcentajeAlcanzado;
  final String? color;

  static MetaAhorro deJson(Map<String, dynamic> j) => MetaAhorro(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    tipoAsignacion: TipoAsignacion.desde(j['tipoAsignacion'] as String),
    valor: (j['valor'] as num).toDouble(),
    saldoAcumulado: (j['saldoAcumulado'] as num).toDouble(),
    prioridad: j['prioridad'] as int,
    activa: j['activa'] as bool,
    metaMonto: (j['metaMonto'] as num?)?.toDouble(),
    porcentajeAlcanzado: (j['porcentajeAlcanzado'] as num?)?.toDouble(),
    color: j['color'] as String?,
  );
}

class PlantillaGasto {
  const PlantillaGasto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.montoDefault,
    required this.activo,
    required this.orden,
    this.diaVencimiento,
  });

  final String id;
  final String nombre;
  final CategoriaGasto categoria;
  final double montoDefault;
  final bool activo;
  final int orden;
  final int? diaVencimiento;

  static PlantillaGasto deJson(Map<String, dynamic> j) => PlantillaGasto(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    categoria: CategoriaGasto.desde(j['categoria'] as String),
    montoDefault: (j['montoDefault'] as num).toDouble(),
    activo: j['activo'] as bool,
    orden: j['orden'] as int,
    diaVencimiento: j['diaVencimiento'] as int?,
  );
}
