import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cliente_api.dart';
import '../datos/repositorio_transporte.dart';
import '../dominio/modelos.dart';
import 'mes.dart';
import 'proveedores.dart';

final repositorioTransporteProvider = Provider<RepositorioTransporte>(
  (ref) => RepositorioTransporte(ref.watch(clienteApiProvider)),
);

/// Calendario y cálculo de transporte del mes.
class DatosTransporte {
  const DatosTransporte({
    required this.resumen,
    required this.configuracion,
    required this.escenarios,
  });

  final ResumenTransporte resumen;
  final ConfigTransporte configuracion;
  final Escenarios escenarios;

  /// Días agrupados por semana, con relleno al inicio para que la primera columna sea lunes.
  ///
  /// Las posiciones vacías se representan con `null`, que es lo que la rejilla dibuja como
  /// hueco antes del día 1.
  List<List<DiaTransporte?>> get semanas {
    if (resumen.dias.isEmpty) return const [];

    final relleno = resumen.dias.first.fecha.weekday - 1;
    final celdas = <DiaTransporte?>[
      ...List<DiaTransporte?>.filled(relleno, null),
      ...resumen.dias,
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }

    return [
      for (var i = 0; i < celdas.length; i += 7) celdas.sublist(i, i + 7),
    ];
  }

  /// Cuánto se lleva gastado frente a lo presupuestado para todo el mes.
  double get proporcionConfirmada => resumen.costoTotal == 0
      ? 0
      : (resumen.costoConfirmado / resumen.costoTotal).clamp(0.0, 1.0);
}

class ControladorTransporte extends StateNotifier<AsyncValue<DatosTransporte>> {
  ControladorTransporte(this._repositorio, this._mesId, this._alCambiarCosto)
    : super(const AsyncValue.loading()) {
    if (_mesId != null) cargar();
  }

  final RepositorioTransporte _repositorio;
  final String? _mesId;

  /// Se invoca tras cada cambio para que el resumen del mes refleje el nuevo costo: el
  /// transporte es también un gasto del presupuesto.
  final void Function() _alCambiarCosto;

  Future<void> cargar() async {
    final id = _mesId;
    if (id == null) return;

    state = const AsyncValue.loading();
    try {
      // Las tres peticiones son independientes; lanzarlas a la vez evita encadenar tres
      // esperas cuando el servidor arranca en frío.
      final (resumen, config, escenarios) = await (
        _repositorio.resumen(id),
        _repositorio.configuracion(id),
        _repositorio.escenarios(id),
      ).wait;

      state = AsyncValue.data(
        DatosTransporte(
          resumen: resumen,
          configuracion: config,
          escenarios: escenarios,
        ),
      );
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }

  Future<void> cambiarTipoDia(String diaId, TipoDia tipo) =>
      _aplicar((id) => _repositorio.cambiarTipoDia(id, diaId, tipo));

  Future<void> fijarPasajes(String diaId, int pasajes) =>
      _aplicar((id) => _repositorio.fijarPasajes(id, diaId, pasajes));

  Future<void> confirmarDia(String diaId, bool confirmado) =>
      _aplicar((id) => _repositorio.confirmarDia(id, diaId, confirmado));

  Future<void> cambiarValorPasaje(double valor) => _aplicar(
    (id) => _repositorio.actualizarConfiguracion(id, valorPasaje: valor),
  );

  /// Cambia lo que cobra el sistema de recarga por operación.
  ///
  /// A partir de ahí, cada abono al transporte apunta esa comisión como una compra del día a
  /// día. Con cero deja de apuntarse.
  Future<void> cambiarComisionRecarga(double valor) => _aplicar(
    (id) => _repositorio.actualizarConfiguracion(id, comisionRecarga: valor),
  );

  Future<void> cambiarDiasKarate(Set<int> dias) => _aplicar(
    (id) => _repositorio.actualizarConfiguracion(id, diasKarate: dias),
  );

  /// Cambia los días remotos previstos y vuelve a repartirlos por el calendario.
  Future<void> cambiarDiasRemotos(int porSemana) => _aplicar(
    (id) => _repositorio.actualizarConfiguracion(
      id,
      diasRemotosPorSemana: porSemana,
      regenerarClasificacion: true,
    ),
  );

  Future<void> regenerar() => _aplicar((id) => _repositorio.regenerar(id));

  /// Aplica un cambio y refresca el resumen sin volver al estado de carga, para que el
  /// calendario no parpadee tras cada toque.
  Future<void> _aplicar(
    Future<ResumenTransporte> Function(String mesId) accion,
  ) async {
    final id = _mesId;
    final actual = state.valueOrNull;
    if (id == null || actual == null) return;

    try {
      final resumen = await accion(id);
      // Los escenarios dependen de la configuración, así que se recalculan aparte.
      final escenarios = await _repositorio.escenarios(id);
      final config = await _repositorio.configuracion(id);

      state = AsyncValue.data(
        DatosTransporte(
          resumen: resumen,
          configuracion: config,
          escenarios: escenarios,
        ),
      );
      _alCambiarCosto();
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }
}

final transporteProvider =
    StateNotifierProvider<ControladorTransporte, AsyncValue<DatosTransporte>>((
      ref,
    ) {
      // Depender del mes en curso hace que el calendario se recargue solo al cambiar de mes.
      final mesId = ref.watch(
        mesProvider.select((m) => m.valueOrNull?.resumen.mesId),
      );

      return ControladorTransporte(
        ref.watch(repositorioTransporteProvider),
        mesId,
        () => ref.read(mesProvider.notifier).refrescar(),
      );
    });
