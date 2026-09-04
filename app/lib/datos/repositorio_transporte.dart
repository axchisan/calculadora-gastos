import '../dominio/modelos.dart';
import 'cliente_api.dart';

/// Configuración del cálculo de transporte de un mes.
class ConfigTransporte {
  const ConfigTransporte({
    required this.valorPasaje,
    required this.comisionRecarga,
    required this.pasajesDiaOficina,
    required this.pasajesExtraKarate,
    required this.pasajesKarateDesdeCasa,
    required this.diasLaborales,
    required this.diasKarate,
    required this.diasRemotosPorSemana,
    this.presupuestoManual,
  });

  final double valorPasaje;

  /// Lo que cobra el sistema de recarga por cada operación.
  ///
  /// Es fija por recarga y no proporcional, así que recargar de a poco sale más caro. Cero
  /// significa que no se cobra ninguna.
  final double comisionRecarga;
  final int pasajesDiaOficina;
  final int pasajesExtraKarate;

  /// Pasajes cuando hay karate en un día no presencial: casa → karate → casa.
  final int pasajesKarateDesdeCasa;

  /// Días de la semana en formato ISO: 1 = lunes … 7 = domingo.
  final Set<int> diasLaborales;
  final Set<int> diasKarate;

  final int diasRemotosPorSemana;

  /// Lo que va a costar el mes, puesto a mano.
  ///
  /// Nulo significa que manda el calendario. Se fija cuando no hay rutina que proyectar —un mes
  /// sin empleo, unas vacaciones— y lo que se sabe no es cuántos pasajes se van a gastar sino
  /// cuánto se va a recargar.
  final double? presupuestoManual;

  bool get tienePresupuestoFijado => presupuestoManual != null;

  static ConfigTransporte deJson(Map<String, dynamic> j) => ConfigTransporte(
    valorPasaje: (j['valorPasaje'] as num).toDouble(),
    comisionRecarga: (j['comisionRecarga'] as num?)?.toDouble() ?? 0,
    pasajesDiaOficina: j['pasajesDiaOficina'] as int,
    pasajesExtraKarate: j['pasajesExtraKarate'] as int,
    pasajesKarateDesdeCasa: j['pasajesKarateDesdeCasa'] as int,
    diasLaborales: _aDias(j['diasLaborales']),
    diasKarate: _aDias(j['diasKarate']),
    diasRemotosPorSemana: j['diasRemotosPorSemana'] as int,
    presupuestoManual: (j['presupuestoManual'] as num?)?.toDouble(),
  );

  /// La API devuelve los días como nombres del enum de Java (`MONDAY`), no como números.
  static Set<int> _aDias(dynamic valor) {
    const nombres = {
      'MONDAY': 1,
      'TUESDAY': 2,
      'WEDNESDAY': 3,
      'THURSDAY': 4,
      'FRIDAY': 5,
      'SATURDAY': 6,
      'SUNDAY': 7,
    };
    if (valor is! List) return {};
    return valor
        .map((e) => e is int ? e : nombres[e.toString()] ?? 0)
        .where((d) => d > 0)
        .toSet();
  }

  static const Map<int, String> nombresIso = {
    1: 'MONDAY',
    2: 'TUESDAY',
    3: 'WEDNESDAY',
    4: 'THURSDAY',
    5: 'FRIDAY',
    6: 'SATURDAY',
    7: 'SUNDAY',
  };
}

/// Proyección del mes bajo un supuesto de días remotos.
class Escenario {
  const Escenario({
    required this.totalPasajes,
    required this.costoTotal,
    required this.diasOficina,
    required this.diasRemotos,
  });

  final int totalPasajes;
  final double costoTotal;
  final int diasOficina;
  final int diasRemotos;

  static Escenario deJson(Map<String, dynamic> j) => Escenario(
    totalPasajes: j['totalPasajes'] as int,
    costoTotal: (j['costoTotal'] as num).toDouble(),
    diasOficina: j['diasOficina'] as int,
    diasRemotos: j['diasRemotos'] as int,
  );
}

class Escenarios {
  const Escenarios({
    required this.optimista,
    required this.esperado,
    required this.pesimista,
    required this.rango,
  });

  final Escenario optimista;
  final Escenario esperado;
  final Escenario pesimista;

  /// Diferencia entre el peor y el mejor caso.
  final double rango;

  static Escenarios deJson(Map<String, dynamic> j) => Escenarios(
    optimista: Escenario.deJson(j['optimista'] as Map<String, dynamic>),
    esperado: Escenario.deJson(j['esperado'] as Map<String, dynamic>),
    pesimista: Escenario.deJson(j['pesimista'] as Map<String, dynamic>),
    rango: (j['rango'] as num).toDouble(),
  );
}

/// Acceso al calendario y al cálculo de transporte.
///
/// Todas las operaciones que modifican algo devuelven el resumen recalculado, de modo que la
/// pantalla se actualiza con una sola petición.
class RepositorioTransporte {
  const RepositorioTransporte(this._api);

  final ClienteApi _api;

  Future<ResumenTransporte> resumen(String mesId) async {
    final datos = await _api.obtener<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte',
    );
    return ResumenTransporte.deJson(datos);
  }

  Future<ConfigTransporte> configuracion(String mesId) async {
    final datos = await _api.obtener<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/configuracion',
    );
    return ConfigTransporte.deJson(datos);
  }

  Future<Escenarios> escenarios(String mesId) async {
    final datos = await _api.obtener<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/escenarios',
    );
    return Escenarios.deJson(datos);
  }

  /// Reclasifica un día: oficina, remoto, vacaciones o ausencia.
  Future<ResumenTransporte> cambiarTipoDia(
    String mesId,
    String diaId,
    TipoDia tipo,
  ) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/dias/$diaId/tipo',
      cuerpo: {'tipo': tipo.codigo},
    );
    return ResumenTransporte.deJson(datos);
  }

  /// Fija a mano los pasajes de un día, protegiéndolos de los recálculos.
  Future<ResumenTransporte> fijarPasajes(
    String mesId,
    String diaId,
    int pasajes,
  ) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/dias/$diaId/pasajes',
      cuerpo: {'pasajes': pasajes},
    );
    return ResumenTransporte.deJson(datos);
  }

  /// Marca que el día ya transcurrió, para comparar lo presupuestado con lo real.
  Future<ResumenTransporte> confirmarDia(
    String mesId,
    String diaId,
    bool confirmado,
  ) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/dias/$diaId/confirmar',
      cuerpo: {'confirmado': confirmado},
    );
    return ResumenTransporte.deJson(datos);
  }

  /// Cambia los parámetros del cálculo.
  ///
  /// [regenerarClasificacion] vuelve a repartir los días remotos desde cero. Cambiar solo la
  /// tarifa no debería descartar los ajustes hechos en el calendario.
  Future<ResumenTransporte> actualizarConfiguracion(
    String mesId, {
    double? valorPasaje,
    double? comisionRecarga,
    int? pasajesDiaOficina,
    int? pasajesExtraKarate,
    int? pasajesKarateDesdeCasa,
    Set<int>? diasLaborales,
    Set<int>? diasKarate,
    int? diasRemotosPorSemana,
    bool regenerarClasificacion = false,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/configuracion',
      cuerpo: {
        'valorPasaje': ?valorPasaje,
        'comisionRecarga': ?comisionRecarga,
        'pasajesDiaOficina': ?pasajesDiaOficina,
        'pasajesExtraKarate': ?pasajesExtraKarate,
        'pasajesKarateDesdeCasa': ?pasajesKarateDesdeCasa,
        if (diasLaborales != null)
          'diasLaborales': diasLaborales
              .map((d) => ConfigTransporte.nombresIso[d])
              .toList(),
        if (diasKarate != null)
          'diasKarate': diasKarate
              .map((d) => ConfigTransporte.nombresIso[d])
              .toList(),
        'diasRemotosPorSemana': ?diasRemotosPorSemana,
        'regenerarClasificacion': regenerarClasificacion,
      },
    );
    return ResumenTransporte.deJson(datos);
  }

  /// Fija a mano lo que va a costar el mes, o vuelve al cálculo por calendario con nulo.
  ///
  /// El calendario se sigue calculando por debajo: lo fijado solo sustituye a la cifra que llega
  /// al presupuesto, así que volver atrás no cuesta haber perdido la rutina.
  Future<ResumenTransporte> fijarPresupuesto(
    String mesId,
    double? presupuesto,
  ) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/presupuesto',
      cuerpo: {'presupuesto': presupuesto},
    );
    return ResumenTransporte.deJson(datos);
  }

  /// Descarta los ajustes del calendario y vuelve a proponerlo desde cero.
  Future<ResumenTransporte> regenerar(String mesId) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/meses/$mesId/transporte/regenerar',
    );
    return ResumenTransporte.deJson(datos);
  }
}
