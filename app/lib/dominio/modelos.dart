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
  antojos('ANTOJOS', 'Antojos'),
  cuidadoPersonal('CUIDADO_PERSONAL', 'Cuidado personal'),
  comisiones('COMISIONES', 'Comisiones'),
  ocio('OCIO', 'Ocio'),
  ropa('ROPA', 'Ropa'),
  hogar('HOGAR', 'Hogar'),
  otro('OTRO', 'Otro');

  const CategoriaGasto(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static CategoriaGasto desde(String codigo) => CategoriaGasto.values
      .firstWhere((c) => c.codigo == codigo, orElse: () => CategoriaGasto.otro);

  /// Las que tienen sentido en una compra suelta del día a día.
  ///
  /// Se dejan fuera las que solo aparecen en compromisos mensuales: nadie compra «vivienda» ni
  /// «suscripciones» sobre la marcha, y verlas en la lista solo estorba al elegir deprisa.
  static const List<CategoriaGasto> deCompras = [
    antojos,
    alimentacion,
    transporte,
    salud,
    cuidadoPersonal,
    ocio,
    hogar,
    ropa,
    comisiones,
    herramientas,
    otro,
  ];
}

/// De dónde salió el dinero de una compra.
///
/// Determina cuándo sale: con efectivo y débito, en el acto; con crédito, cuando venza el corte
/// de la tarjeta, que puede ser uno o dos meses después.
enum MedioPago {
  efectivo('EFECTIVO', 'Efectivo'),
  debito('DEBITO', 'Débito'),
  credito('CREDITO', 'Crédito');

  const MedioPago(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static MedioPago desde(String codigo) => MedioPago.values.firstWhere(
    (m) => m.codigo == codigo,
    orElse: () => MedioPago.efectivo,
  );

  bool get saleAlInstante => this != MedioPago.credito;
}

enum TipoTarjeta {
  debito('DEBITO', 'Débito'),
  credito('CREDITO', 'Crédito');

  const TipoTarjeta(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoTarjeta desde(String codigo) => TipoTarjeta.values.firstWhere(
    (t) => t.codigo == codigo,
    orElse: () => TipoTarjeta.debito,
  );

  MedioPago get medioPago =>
      this == TipoTarjeta.credito ? MedioPago.credito : MedioPago.debito;
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
    required this.comprasDelMes,
    required this.comprasInmediatas,
    required this.comprasACredito,
    required this.cortesTarjetaPendientes,
    required this.cortesTarjetaPagados,
    required this.cuotasCreditoPendientes,
    required this.cuotasCreditoPagadas,
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

  /// Todo lo comprado en el día a día durante el mes, se haya pagado ya o quede a deber.
  final double comprasDelMes;

  /// Lo comprado que salió del bolsillo en el acto: efectivo y débito.
  final double comprasInmediatas;

  /// Lo cargado a tarjetas de crédito este mes. No sale ahora, sale cuando venza el corte.
  final double comprasACredito;

  /// Cortes de tarjeta que vencen este mes y siguen sin pagar.
  final double cortesTarjetaPendientes;

  /// Cortes que vencían este mes y ya se saldaron.
  final double cortesTarjetaPagados;

  /// Cuotas de créditos que vencen este mes y siguen sin pagar.
  final double cuotasCreditoPendientes;

  /// Cuotas de créditos que vencían este mes y ya se pagaron.
  final double cuotasCreditoPagadas;

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

  /// Dinero que ya salió este mes: gastos, abonos a deudas, ahorro, compras del día a día y
  /// cortes de tarjeta ya saldados.
  ///
  /// Contar solo los gastos dejaba fuera los abonos a deudas, que salen del bolsillo igual, y
  /// después las compras diarias, que salen igual de rápido aunque sean pequeñas.
  double get salidaReal =>
      gastoPagado +
      abonosDeuda +
      aporteAhorro +
      comprasInmediatas +
      cortesTarjetaPagados +
      cuotasCreditoPagadas;

  /// Indica si hay algo cargado a crédito este mes que se pagará más adelante.
  ///
  /// Es la cifra que conviene mirar de reojo: no falta este mes, pero ya está gastada.
  bool get tieneCreditoPorVencer => comprasACredito > 0;

  /// Lo que falta por cubrir: gastos sin pagar más las cuotas de deuda pendientes.
  ///
  /// Una deuda es algo más que hay que pagar este mes, así que cuenta aquí igual que un gasto
  /// sin saldar. Nunca baja de cero: abonar por encima de la cuota no genera un pendiente
  /// negativo.
  double get pendienteTotal {
    final falta = comprometidoConCuotas - salidaReal;
    return falta < 0 ? 0 : falta;
  }

  /// Proporción de todo lo que hay que pagar este mes que ya está cubierta.
  double get proporcionCubierta => comprometidoConCuotas == 0
      ? 0
      : (salidaReal / comprometidoConCuotas).clamp(0.0, 1.0);

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
      // Con valor por defecto: un resumen guardado en el caché antes de que existieran las
      // compras no trae estos campos, y sin esto la aplicación fallaría al abrir sin conexión.
      comprasDelMes: (j['comprasDelMes'] as num?)?.toDouble() ?? 0,
      comprasInmediatas: (j['comprasInmediatas'] as num?)?.toDouble() ?? 0,
      comprasACredito: (j['comprasACredito'] as num?)?.toDouble() ?? 0,
      cortesTarjetaPendientes:
          (j['cortesTarjetaPendientes'] as num?)?.toDouble() ?? 0,
      cortesTarjetaPagados:
          (j['cortesTarjetaPagados'] as num?)?.toDouble() ?? 0,
      cuotasCreditoPendientes:
          (j['cuotasCreditoPendientes'] as num?)?.toDouble() ?? 0,
      cuotasCreditoPagadas:
          (j['cuotasCreditoPagadas'] as num?)?.toDouble() ?? 0,
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

/// Cómo se reconoce una tarjeta en las notificaciones de pago del teléfono.
class AliasTarjeta {
  const AliasTarjeta({required this.id, this.apodo, this.ultimos4});

  final String id;

  /// El nombre que la tarjeta tiene dentro de Google Wallet: «crédito física».
  final String? apodo;

  /// Los cuatro últimos dígitos, que publica el banco.
  final String? ultimos4;

  /// El apodo en minúsculas y sin tildes, para poder compararlo.
  ///
  /// Hace falta porque los apodos se escriben a mano y no siempre igual: en la misma billetera
  /// conviven «crédito física», con tilde, y «credito digital», sin ella.
  String? get apodoNormalizado => normalizar(apodo);

  static String? normalizar(String? texto) {
    if (texto == null) return null;

    const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const sinTilde = 'aaaaaeeeeiiiiooooouuuunc';

    final minuscula = texto.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final letra in minuscula.split('')) {
      final posicion = conTilde.indexOf(letra);
      buffer.write(posicion == -1 ? letra : sinTilde[posicion]);
    }
    return buffer.toString();
  }

  static AliasTarjeta deJson(Map<String, dynamic> j) => AliasTarjeta(
    id: j['id'] as String,
    apodo: j['apodo'] as String?,
    ultimos4: j['ultimos4'] as String?,
  );
}

/// Una tarjeta con la que se paga.
class Tarjeta {
  const Tarjeta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.activa,
    this.diaCorte,
    this.diaPago,
    this.color,
    this.alias = const [],
  });

  final String id;
  final String nombre;
  final TipoTarjeta tipo;
  final bool activa;

  /// Día en que cierra el periodo de consumo. Solo en las de crédito.
  final int? diaCorte;

  /// Día del mes siguiente al corte en que vence el pago. Solo en las de crédito.
  final int? diaPago;

  final String? color;

  /// Con qué apodos y dígitos se reconoce en las notificaciones de pago.
  final List<AliasTarjeta> alias;

  bool get esDeCredito => tipo == TipoTarjeta.credito;

  /// Indica si esta tarjeta es la de una notificación de pago.
  ///
  /// Los cuatro dígitos mandan sobre el apodo: no dependen de cómo se haya escrito nada.
  bool reconoce({String? apodo, String? ultimos4}) {
    if (ultimos4 != null) {
      if (alias.any((a) => a.ultimos4 == ultimos4)) return true;
    }
    if (apodo != null) {
      final buscado = AliasTarjeta.normalizar(apodo);
      if (alias.any((a) => a.apodoNormalizado == buscado)) return true;
    }
    return false;
  }

  /// Descripción corta del ciclo, del estilo «corte 15 · pago 4».
  String? get resumenCiclo => diaCorte == null || diaPago == null
      ? null
      : 'corte $diaCorte · pago $diaPago';

  /// Fecha en que vencería una compra hecha ese día, o null si la tarjeta no tiene ciclo.
  ///
  /// El servidor es quien decide de verdad el mes de pago al guardar la compra; esto solo
  /// existe para poder avisar antes de guardar, mientras se elige el medio de pago. Es la
  /// diferencia entre enterarse de que algo se paga en octubre ahora o después.
  DateTime? vencimientoDe(DateTime compra) {
    final corte = diaCorte;
    final pago = diaPago;
    if (corte == null || pago == null) return null;

    // Pasado el día de corte, la compra ya no cabe en el periodo que acaba de cerrar y espera
    // al siguiente, con lo que su pago se va un mes más allá.
    final mesDelCorte = compra.day > corte ? compra.month + 1 : compra.month;
    // DateTime normaliza los meses fuera de rango: el mes 13 pasa a enero del año siguiente.
    return DateTime(compra.year, mesDelCorte + 1, pago);
  }

  static Tarjeta deJson(Map<String, dynamic> j) => Tarjeta(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    tipo: TipoTarjeta.desde(j['tipo'] as String),
    activa: j['activa'] as bool,
    diaCorte: (j['diaCorte'] as num?)?.toInt(),
    diaPago: (j['diaPago'] as num?)?.toInt(),
    color: j['color'] as String?,
    alias:
        (j['alias'] as List<dynamic>?)
            ?.map((e) => AliasTarjeta.deJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// Una compra del día a día.
class Compra {
  const Compra({
    required this.id,
    required this.fecha,
    required this.descripcion,
    required this.categoria,
    required this.monto,
    required this.medio,
    required this.periodoPago,
    required this.vencimiento,
    required this.pagado,
    this.tarjetaId,
    this.tarjetaNombre,
    this.nota,
  });

  final String id;
  final DateTime fecha;
  final String descripcion;
  final CategoriaGasto categoria;
  final double monto;
  final MedioPago medio;

  /// Mes del que sale el dinero. Con crédito no coincide con el de la compra.
  final DateTime periodoPago;

  /// Fecha exacta en que hay que pagarla.
  final DateTime vencimiento;

  /// Con efectivo o débito siempre cierto; con crédito, hasta que se salde el corte.
  final bool pagado;

  final String? tarjetaId;
  final String? tarjetaNombre;
  final String? nota;

  /// Indica si el dinero de esta compra todavía no ha salido.
  bool get quedaPorPagar => !pagado;

  static Compra deJson(Map<String, dynamic> j) {
    final partes = (j['periodoPago'] as String).split('-');

    return Compra(
      id: j['id'] as String,
      fecha: DateTime.parse(j['fecha'] as String),
      descripcion: j['descripcion'] as String,
      categoria: CategoriaGasto.desde(j['categoria'] as String),
      monto: (j['monto'] as num).toDouble(),
      medio: MedioPago.desde(j['medio'] as String),
      periodoPago: DateTime(int.parse(partes[0]), int.parse(partes[1])),
      vencimiento: DateTime.parse(j['vencimiento'] as String),
      pagado: j['pagado'] as bool,
      tarjetaId: j['tarjetaId'] as String?,
      tarjetaNombre: j['tarjetaNombre'] as String?,
      nota: j['nota'] as String?,
    );
  }
}

/// Cuánto se gastó un día concreto, para ver el ritmo del mes.
class TotalDia {
  const TotalDia({required this.fecha, required this.total});

  final DateTime fecha;
  final double total;

  static TotalDia deJson(Map<String, dynamic> j) => TotalDia(
    fecha: DateTime.parse(j['fecha'] as String),
    total: (j['total'] as num).toDouble(),
  );
}

/// Las compras de un mes con sus totales.
class ComprasDelMes {
  const ComprasDelMes({
    required this.total,
    required this.inmediato,
    required this.aCredito,
    required this.porDia,
    required this.compras,
  });

  final double total;
  final double inmediato;
  final double aCredito;
  final List<TotalDia> porDia;
  final List<Compra> compras;

  static const vacio = ComprasDelMes(
    total: 0,
    inmediato: 0,
    aCredito: 0,
    porDia: [],
    compras: [],
  );

  /// Cuánto se gasta al día de media, contando solo los días en que hubo alguna compra.
  double get promedioPorDia => porDia.isEmpty ? 0 : total / porDia.length;

  /// El día en que más se gastó.
  TotalDia? get diaMasCaro => porDia.isEmpty
      ? null
      : porDia.reduce((a, b) => a.total >= b.total ? a : b);

  static ComprasDelMes deJson(Map<String, dynamic> j) => ComprasDelMes(
    total: (j['total'] as num).toDouble(),
    inmediato: (j['inmediato'] as num).toDouble(),
    aCredito: (j['aCredito'] as num).toDouble(),
    porDia: (j['porDia'] as List<dynamic>)
        .map((e) => TotalDia.deJson(e as Map<String, dynamic>))
        .toList(),
    compras: (j['compras'] as List<dynamic>)
        .map((e) => Compra.deJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Lo que hay que pagarle a una tarjeta en un mes.
class CorteTarjeta {
  const CorteTarjeta({
    required this.tarjetaId,
    required this.tarjetaNombre,
    required this.periodo,
    required this.total,
    required this.pendiente,
    required this.saldado,
    required this.compras,
    this.vencimiento,
  });

  final String tarjetaId;
  final String tarjetaNombre;
  final DateTime periodo;
  final double total;
  final double pendiente;
  final bool saldado;
  final List<Compra> compras;
  final DateTime? vencimiento;

  static CorteTarjeta deJson(Map<String, dynamic> j) {
    final partes = (j['periodo'] as String).split('-');

    return CorteTarjeta(
      tarjetaId: j['tarjetaId'] as String,
      tarjetaNombre: j['tarjetaNombre'] as String,
      periodo: DateTime(int.parse(partes[0]), int.parse(partes[1])),
      total: (j['total'] as num).toDouble(),
      pendiente: (j['pendiente'] as num).toDouble(),
      saldado: j['saldado'] as bool,
      compras: (j['compras'] as List<dynamic>)
          .map((e) => Compra.deJson(e as Map<String, dynamic>))
          .toList(),
      vencimiento: j['vencimiento'] == null
          ? null
          : DateTime.parse(j['vencimiento'] as String),
    );
  }
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
