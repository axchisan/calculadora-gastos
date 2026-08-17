import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cliente_api.dart';
import '../datos/repositorio_compras.dart';
import '../dominio/modelos.dart';
import 'mes.dart';
import 'proveedores.dart';

final repositorioComprasProvider = Provider<RepositorioCompras>(
  (ref) => RepositorioCompras(ref.watch(clienteApiProvider)),
);

/// Las tarjetas del usuario. Cambian muy poco, así que se cargan una vez y se reutilizan.
final tarjetasProvider = FutureProvider<List<Tarjeta>>(
  (ref) => ref.watch(repositorioComprasProvider).tarjetas(),
);

/// Solo las de crédito activas, que son las que hacen falta al elegir el medio de pago.
final tarjetasDeCreditoProvider = Provider<List<Tarjeta>>((ref) {
  return ref
      .watch(tarjetasProvider)
      .maybeWhen(
        data: (tarjetas) =>
            tarjetas.where((t) => t.esDeCredito && t.activa).toList(),
        orElse: () => const <Tarjeta>[],
      );
});

/// Cortes de tarjeta que vencen en el periodo que se está viendo.
final cortesDelPeriodoProvider = FutureProvider<List<CorteTarjeta>>((ref) {
  return ref
      .watch(repositorioComprasProvider)
      .cortes(ref.watch(periodoProvider));
});

/// Las compras del día a día del mes en pantalla.
///
/// Vive aparte del [mesProvider] porque son listas distintas con ritmos distintos: los gastos
/// fijos se tocan un par de veces al mes y las compras, varias veces al día. Mezclarlos
/// obligaría a recargar la lista entera de gastos cada vez que se apunta un chocorramo.
class ControladorCompras extends StateNotifier<AsyncValue<ComprasDelMes>> {
  ControladorCompras(this._repositorio, this._mesId, this._alCambiar)
    : super(const AsyncValue.loading()) {
    cargar();
  }

  final RepositorioCompras _repositorio;
  final String? _mesId;

  /// Toda compra mueve el disponible del mes, así que hay que refrescar el resumen.
  final void Function() _alCambiar;

  Future<void> cargar() async {
    final id = _mesId;
    if (id == null) {
      // El mes todavía no se ha creado; no hay nada que cargar y tampoco es un error.
      state = const AsyncValue.data(ComprasDelMes.vacio);
      return;
    }
    state = const AsyncValue.loading();
    await _recargar(id);
  }

  Future<void> refrescar() async {
    final id = _mesId;
    if (id != null) await _recargar(id);
  }

  Future<void> registrar({
    required String descripcion,
    required double monto,
    required CategoriaGasto categoria,
    DateTime? fecha,
    MedioPago? medio,
    String? tarjetaId,
    String? nota,
  }) async {
    final id = _mesId;
    if (id == null) return;

    await _repositorio.registrar(
      id,
      descripcion: descripcion,
      monto: monto,
      categoria: categoria,
      fecha: fecha,
      medio: medio,
      tarjetaId: tarjetaId,
      nota: nota,
    );
    await refrescar();
    _alCambiar();
  }

  Future<void> actualizar(
    String compraId, {
    String? descripcion,
    double? monto,
    CategoriaGasto? categoria,
    DateTime? fecha,
    MedioPago? medio,
    String? tarjetaId,
    String? nota,
  }) async {
    await _repositorio.actualizar(
      compraId,
      descripcion: descripcion,
      monto: monto,
      categoria: categoria,
      fecha: fecha,
      medio: medio,
      tarjetaId: tarjetaId,
      nota: nota,
    );
    await refrescar();
    _alCambiar();
  }

  Future<void> eliminar(String compraId) async {
    await _repositorio.eliminar(compraId);
    await refrescar();
    _alCambiar();
  }

  Future<void> _recargar(String mesId) async {
    try {
      state = AsyncValue.data(await _repositorio.delMes(mesId));
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }
}

final comprasProvider =
    StateNotifierProvider<ControladorCompras, AsyncValue<ComprasDelMes>>((ref) {
      // Se observa el identificador del mes para reaccionar cuando termina de crearse: hasta
      // entonces no hay nada a lo que colgar las compras.
      return ControladorCompras(
        ref.watch(repositorioComprasProvider),
        ref.watch(mesIdProvider),
        () => ref.read(mesProvider.notifier).refrescar(),
      );
    });

/// Alta, cambios y bajas de tarjetas.
///
/// No lleva estado propio: las tarjetas viven en [tarjetasProvider] y aquí solo se invalida
/// para que se vuelvan a leer. Son cuatro registros que cambian dos veces al año.
class ControladorTarjetas {
  const ControladorTarjetas(this._repositorio, this._invalidar);

  final RepositorioCompras _repositorio;
  final void Function() _invalidar;

  Future<void> crear({
    required String nombre,
    required TipoTarjeta tipo,
    int? diaCorte,
    int? diaPago,
  }) async {
    await _repositorio.crearTarjeta(
      nombre: nombre,
      tipo: tipo,
      diaCorte: diaCorte,
      diaPago: diaPago,
    );
    _invalidar();
  }

  Future<void> actualizar(
    String tarjetaId, {
    String? nombre,
    int? diaCorte,
    int? diaPago,
    bool? activa,
  }) async {
    await _repositorio.actualizarTarjeta(
      tarjetaId,
      nombre: nombre,
      diaCorte: diaCorte,
      diaPago: diaPago,
      activa: activa,
    );
    _invalidar();
  }

  Future<void> eliminar(String tarjetaId) async {
    await _repositorio.eliminarTarjeta(tarjetaId);
    _invalidar();
  }

  Future<void> anadirAlias(
    String tarjetaId, {
    String? apodo,
    String? ultimos4,
  }) async {
    await _repositorio.anadirAlias(tarjetaId, apodo: apodo, ultimos4: ultimos4);
    _invalidar();
  }

  Future<void> eliminarAlias(String aliasId) async {
    await _repositorio.eliminarAlias(aliasId);
    _invalidar();
  }
}

final controladorTarjetasProvider = Provider<ControladorTarjetas>((ref) {
  return ControladorTarjetas(
    ref.watch(repositorioComprasProvider),
    () => ref.invalidate(tarjetasProvider),
  );
});

/// Saldar o reabrir el corte de una tarjeta.
final saldarCorteProvider =
    Provider<Future<void> Function(String, DateTime, {required bool pagado})>((
      ref,
    ) {
      return (tarjetaId, periodo, {required bool pagado}) async {
        await ref
            .read(repositorioComprasProvider)
            .saldarCorte(tarjetaId, periodo, pagado: pagado);
        ref.invalidate(cortesDelPeriodoProvider);
        await ref.read(mesProvider.notifier).refrescar();
      };
    });
