import 'modelos.dart';

/// Cómo se registra un movimiento detectado al aceptarlo.
enum DestinoDetectado {
  compra('COMPRA', 'Compra'),
  gasto('GASTO', 'Gasto'),
  ingreso('INGRESO', 'Ingreso'),
  abono('ABONO', 'Deuda');

  const DestinoDetectado(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static DestinoDetectado? desde(String? codigo) {
    for (final d in values) {
      if (d.codigo == codigo) return d;
    }
    return null;
  }
}

/// Un movimiento que llegó del banco (aviso por SMS o correo, o línea del extracto) y espera a
/// que el usuario decida qué hacer con él.
class Detectado {
  const Detectado({
    required this.id,
    required this.origen,
    required this.monto,
    required this.fecha,
    required this.estado,
    this.clase,
    this.hora,
    this.contraparte,
    this.referencia,
    this.motivo,
    this.sugerenciaDestino,
    this.sugerenciaCategoria,
    this.sugerenciaNombre,
    this.sugerenciaObjetivo,
    this.texto = '',
  });

  final String id;

  /// SMS, CORREO, PDF o NOTIFICACION.
  final String origen;

  /// Positivo si entró, negativo si salió.
  final double monto;
  final DateTime fecha;
  final String estado;
  final String? clase;

  /// «18:05:00»; el extracto no la trae.
  final String? hora;
  final String? contraparte;
  final String? referencia;
  final String? motivo;
  final DestinoDetectado? sugerenciaDestino;
  final String? sugerenciaCategoria;
  final String? sugerenciaNombre;

  /// La deuda a la que se abonaría, si la sugerencia es un abono.
  final String? sugerenciaObjetivo;
  final String texto;

  bool get entra => monto > 0;

  /// Si una regla del usuario ya dijo exactamente cómo registrarlo: se puede aceptar en bloque.
  bool get listoParaAceptar => switch (sugerenciaDestino) {
    DestinoDetectado.abono => sugerenciaObjetivo != null,
    DestinoDetectado.ingreso => sugerenciaNombre != null && entra,
    DestinoDetectado.compra ||
    DestinoDetectado.gasto => sugerenciaNombre != null && !entra,
    null => false,
  };

  /// El nombre con que se registraría: el de la regla, o la contraparte en minúsculas
  /// legibles («TIENDA LA ESQUINA» → «Tienda La Esquina»).
  String get nombreSugerido {
    if (sugerenciaNombre case final n? when n.isNotEmpty) return n;
    final c = contraparte;
    if (c == null || c.isEmpty) return entra ? 'Ingreso' : 'Pago';
    if (c == c.toUpperCase()) {
      return c
          .toLowerCase()
          .split(' ')
          .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
          .join(' ');
    }
    return c;
  }

  String get etiquetaOrigen => switch (origen) {
    'SMS' => 'SMS',
    'CORREO' => 'Correo',
    'PDF' => 'Extracto',
    _ => 'Aviso',
  };

  /// Qué tipo de movimiento es, en palabras.
  String get etiquetaClase => switch (clase) {
    'COMPRA' => 'Compra con tarjeta',
    'PAGO' => 'Pago PSE',
    'PAGO_QR' => 'Pago con QR',
    'TRANSFERENCIA_ENVIADA' => 'Transferencia enviada',
    'TRANSFERENCIA_RECIBIDA' => 'Transferencia recibida',
    'NOMINA' => 'Nómina',
    'RETIRO' => 'Retiro',
    'COMISION' => 'Comisión',
    _ => entra ? 'Entrada' : 'Salida',
  };

  CategoriaGasto? get categoriaSugerida {
    final c = sugerenciaCategoria;
    if (c == null) return null;
    for (final x in CategoriaGasto.values) {
      if (x.codigo == c) return x;
    }
    return null;
  }

  TipoIngreso? get tipoIngresoSugerido {
    final c = sugerenciaCategoria;
    if (c == null) return null;
    for (final x in TipoIngreso.values) {
      if (x.codigo == c) return x;
    }
    return null;
  }

  static Detectado deJson(Map<String, dynamic> j) => Detectado(
    id: j['id'] as String,
    origen: j['origen'] as String,
    monto: (j['monto'] as num?)?.toDouble() ?? 0,
    fecha: DateTime.parse(j['fecha'] as String),
    estado: j['estado'] as String,
    clase: j['clase'] as String?,
    hora: j['hora'] as String?,
    contraparte: j['contraparte'] as String?,
    referencia: j['referencia'] as String?,
    motivo: j['motivo'] as String?,
    sugerenciaDestino: DestinoDetectado.desde(
      j['sugerenciaDestino'] as String?,
    ),
    sugerenciaCategoria: j['sugerenciaCategoria'] as String?,
    sugerenciaNombre: j['sugerenciaNombre'] as String?,
    sugerenciaObjetivo: j['sugerenciaObjetivo'] as String?,
    texto: j['texto'] as String? ?? '',
  );
}

/// Lo que dejó la importación de un extracto.
class ResumenImportacion {
  const ResumenImportacion({
    required this.leidos,
    required this.yaEstaban,
    required this.pendientes,
    required this.duplicados,
    required this.yaRegistrados,
    required this.descartados,
    this.anteriores = 0,
    this.desde,
    this.hasta,
  });

  final int leidos;
  final int yaEstaban;
  final int pendientes;
  final int duplicados;
  final int yaRegistrados;
  final int descartados;

  /// Líneas de antes del mes en curso: ya se cuadraron a mano y no se importan.
  final int anteriores;
  final DateTime? desde;
  final DateTime? hasta;

  static ResumenImportacion deJson(Map<String, dynamic> j) =>
      ResumenImportacion(
        leidos: j['leidos'] as int? ?? 0,
        yaEstaban: j['yaEstaban'] as int? ?? 0,
        pendientes: j['pendientes'] as int? ?? 0,
        duplicados: j['duplicados'] as int? ?? 0,
        yaRegistrados: j['yaRegistrados'] as int? ?? 0,
        descartados: j['descartados'] as int? ?? 0,
        desde: j['desde'] == null ? null : DateTime.parse(j['desde'] as String),
        hasta: j['hasta'] == null ? null : DateTime.parse(j['hasta'] as String),
      );

  /// Una frase con lo que pasó: «23 por revisar · 41 ya estaban apuntados».
  String get frase {
    final partes = <String>[
      if (pendientes > 0)
        pendientes == 1 ? '1 por revisar' : '$pendientes por revisar',
      if (yaRegistrados + duplicados > 0)
        '${yaRegistrados + duplicados} ya estaban',
      if (descartados > 0)
        descartados == 1
            ? '1 sin importancia (intereses o retiro)'
            : '$descartados sin importancia (intereses o retiros)',
      if (yaEstaban > 0) '$yaEstaban ya importados antes',
      if (anteriores > 0) '$anteriores de meses anteriores, sin tocar',
    ];
    return partes.isEmpty ? 'Nada nuevo' : partes.join(' · ');
  }
}
