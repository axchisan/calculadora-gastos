import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cliente_api.dart';
import '../datos/repositorio_deudas.dart';
import '../dominio/modelos.dart';
import 'mes.dart';
import 'proveedores.dart';

final repositorioDeudasProvider = Provider<RepositorioDeudas>(
  (ref) => RepositorioDeudas(ref.watch(clienteApiProvider)),
);

/// Deudas del usuario, con lo que suman.
class DatosDeudas {
  const DatosDeudas({required this.deudas});

  final List<Deuda> deudas;

  List<Deuda> get activas => deudas.where((d) => d.activa).toList();
  List<Deuda> get saldadas => deudas.where((d) => !d.activa).toList();

  double get saldoTotal => activas.fold<double>(0, (suma, d) => suma + d.saldo);

  double get montoOriginalTotal =>
      deudas.fold<double>(0, (suma, d) => suma + d.montoOriginal);

  /// Intereses que generarán las deudas activas en un mes.
  double get interesMensualTotal => activas.fold<double>(
    0,
    (suma, d) => suma + (d.interesMensualEstimado ?? 0),
  );

  /// Proporción del total ya saldada.
  double get proporcionPagada => montoOriginalTotal == 0
      ? 1
      : ((montoOriginalTotal - saldoTotal) / montoOriginalTotal).clamp(
          0.0,
          1.0,
        );
}

/// Si se ven todas las deudas de la historia o solo las del mes en pantalla.
///
/// Por defecto se filtra por mes: las deudas saldadas en agosto no significan nada en
/// septiembre, y verlas ahí mezcladas con las de verdad confunde más que ayuda. El histórico
/// sigue estando a un toque de distancia.
final verTodasLasDeudasProvider = StateProvider<bool>((ref) => false);

class ControladorDeudas extends StateNotifier<AsyncValue<DatosDeudas>> {
  ControladorDeudas(this._repositorio, this._periodo, this._alCambiar)
    : super(const AsyncValue.loading()) {
    cargar();
  }

  final RepositorioDeudas _repositorio;

  /// Mes por el que se filtra, o nulo para ver el histórico completo.
  final DateTime? _periodo;

  /// Los abonos vinculados a un mes afectan a su disponible, así que hay que refrescarlo.
  final void Function() _alCambiar;

  Future<void> cargar() async {
    state = const AsyncValue.loading();
    await _recargar();
  }

  Future<void> refrescar() => _recargar();

  Future<void> _recargar() async {
    try {
      final deudas = await _repositorio.listar(periodo: _periodo);
      state = AsyncValue.data(DatosDeudas(deudas: deudas));
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }

  Future<void> crear({
    required String acreedor,
    required TipoDeuda tipo,
    required double montoOriginal,
    double? tasaInteresMensual,
    double? cuotaSugerida,
  }) async {
    await _repositorio.crear(
      acreedor: acreedor,
      tipo: tipo,
      montoOriginal: montoOriginal,
      fechaInicio: _fechaDeAlta(),
      tasaInteresMensual: tasaInteresMensual,
      cuotaSugerida: cuotaSugerida,
    );
    await refrescar();
  }

  /// Con qué fecha nace una deuda creada desde esta pantalla.
  ///
  /// Si se está mirando un mes distinto al actual, la deuda se fecha en ese mes: al registrar
  /// en septiembre algo que se debe en septiembre, lo natural es que aparezca ahí y no en el
  /// mes en el que uno se acordó de apuntarlo.
  DateTime? _fechaDeAlta() {
    final periodo = _periodo;
    if (periodo == null) return null;

    final hoy = DateTime.now();
    final esElMesEnCurso =
        periodo.year == hoy.year && periodo.month == hoy.month;
    return esElMesEnCurso ? null : DateTime(periodo.year, periodo.month, 1);
  }

  Future<void> actualizar(
    String deudaId, {
    String? acreedor,
    TipoDeuda? tipo,
    double? tasaInteresMensual,
    double? cuotaSugerida,
    double? montoOriginal,
  }) async {
    await _repositorio.actualizar(
      deudaId,
      acreedor: acreedor,
      tipo: tipo,
      tasaInteresMensual: tasaInteresMensual,
      cuotaSugerida: cuotaSugerida,
      montoOriginal: montoOriginal,
    );
    await refrescar();
  }

  Future<void> abonar(
    String deudaId, {
    required double monto,
    String? mesId,
    String? nota,
  }) async {
    await _repositorio.abonar(deudaId, monto: monto, mesId: mesId, nota: nota);
    await refrescar();
    _alCambiar();
  }

  Future<void> eliminarAbono(String abonoId) async {
    await _repositorio.eliminarAbono(abonoId);
    await refrescar();
    _alCambiar();
  }

  Future<void> eliminar(String deudaId) async {
    await _repositorio.eliminar(deudaId);
    await refrescar();
    _alCambiar();
  }

  Future<List<AbonoDeuda>> abonos(String deudaId) =>
      _repositorio.abonos(deudaId);
}

final deudasProvider =
    StateNotifierProvider<ControladorDeudas, AsyncValue<DatosDeudas>>((ref) {
      final verTodas = ref.watch(verTodasLasDeudasProvider);

      return ControladorDeudas(
        ref.watch(repositorioDeudasProvider),
        verTodas ? null : ref.watch(periodoProvider),
        () => ref.read(mesProvider.notifier).refrescar(),
      );
    });
