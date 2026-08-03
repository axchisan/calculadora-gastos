import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cliente_api.dart';
import '../datos/repositorio_ahorro.dart';
import '../dominio/modelos.dart';
import 'mes.dart';
import 'proveedores.dart';

final repositorioAhorroProvider = Provider<RepositorioAhorro>(
  (ref) => RepositorioAhorro(ref.watch(clienteApiProvider)),
);

/// Metas de ahorro y el reparto sugerido del mes.
class DatosAhorro {
  const DatosAhorro({required this.metas, required this.distribucion});

  final List<MetaAhorro> metas;

  /// Cuánto propone destinar el sistema a cada meta con el disponible del mes.
  ///
  /// Es una sugerencia y **no mueve dinero**: para materializarla hay que registrar los
  /// movimientos.
  final List<Asignacion> distribucion;

  List<MetaAhorro> get activas => metas.where((m) => m.activa).toList();

  double get saldoTotal =>
      metas.fold<double>(0, (suma, m) => suma + m.saldoAcumulado);

  double get totalSugerido =>
      distribucion.fold<double>(0, (suma, a) => suma + a.monto);
}

class ControladorAhorro extends StateNotifier<AsyncValue<DatosAhorro>> {
  ControladorAhorro(this._repositorio, this._mesId, this._alCambiar)
    : super(const AsyncValue.loading()) {
    cargar();
  }

  final RepositorioAhorro _repositorio;
  final String? _mesId;
  final void Function() _alCambiar;

  Future<void> cargar() async {
    state = const AsyncValue.loading();
    await _leer();
  }

  Future<void> refrescar() => _leer();

  Future<void> _leer() async {
    try {
      final metas = await _repositorio.listar();
      // La distribución depende del mes; sin mes cargado aún, se muestran solo las metas.
      final distribucion = _mesId == null
          ? <Asignacion>[]
          : await _repositorio.distribucion(_mesId);

      state = AsyncValue.data(
        DatosAhorro(metas: metas, distribucion: distribucion),
      );
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }

  Future<void> crear({
    required String nombre,
    required TipoAsignacion tipoAsignacion,
    required double valor,
    double? metaMonto,
    int? prioridad,
  }) async {
    await _repositorio.crear(
      nombre: nombre,
      tipoAsignacion: tipoAsignacion,
      valor: valor,
      metaMonto: metaMonto,
      prioridad: prioridad,
    );
    await refrescar();
  }

  Future<void> registrarMovimiento(
    String metaId, {
    required TipoMovimiento tipo,
    required double monto,
    String? nota,
  }) async {
    await _repositorio.registrarMovimiento(
      metaId,
      tipo: tipo,
      monto: monto,
      mesId: _mesId,
      nota: nota,
    );
    await refrescar();
    _alCambiar();
  }

  /// Materializa el reparto sugerido registrando un aporte por cada meta.
  Future<void> aplicarDistribucion() async {
    final datos = state.valueOrNull;
    if (datos == null) return;

    for (final asignacion in datos.distribucion) {
      if (asignacion.monto <= 0) continue;
      await _repositorio.registrarMovimiento(
        asignacion.metaId,
        tipo: TipoMovimiento.aporte,
        monto: asignacion.monto,
        mesId: _mesId,
        nota: 'Reparto del mes',
      );
    }
    await refrescar();
    _alCambiar();
  }

  Future<void> eliminar(String metaId) async {
    await _repositorio.eliminar(metaId);
    await refrescar();
    _alCambiar();
  }

  Future<List<MovimientoAhorro>> movimientos(String metaId) =>
      _repositorio.movimientos(metaId);
}

final ahorroProvider =
    StateNotifierProvider<ControladorAhorro, AsyncValue<DatosAhorro>>((ref) {
      final mesId = ref.watch(
        mesProvider.select((m) => m.valueOrNull?.resumen.mesId),
      );

      return ControladorAhorro(
        ref.watch(repositorioAhorroProvider),
        mesId,
        () => ref.read(mesProvider.notifier).refrescar(),
      );
    });
