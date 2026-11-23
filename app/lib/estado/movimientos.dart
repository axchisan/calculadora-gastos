import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio/movimientos.dart';
import 'compras.dart';
import 'mes.dart';
import 'proveedores.dart';

/// Lo que entró y salió en el mes que se está viendo, en una sola lista.
///
/// Espera a que el mes exista (el [mesProvider] lo crea si hace falta) y se vuelve a pedir tras
/// cualquier cambio hecho en la app, venga de la pantalla que venga.
final movimientosProvider = FutureProvider<MovimientosDelMes>((ref) async {
  final mesId = ref.watch(mesIdProvider);
  if (mesId == null) {
    // Mientras el mes carga, se queda cargando sin error; al llegar el identificador, este
    // proveedor se reconstruye solo porque lo observa.
    return Completer<MovimientosDelMes>().future;
  }
  ref.alActualizarse(['/api/meses/$mesId'], ref.invalidateSelf);
  final cambios = ref
      .read(clienteApiProvider)
      .cambiosLocales
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(cambios.cancel);
  return ref.watch(repositorioMesesProvider).movimientos(mesId);
});

/// Filtro elegido en Movimientos: todo, lo que entró o lo que salió.
final filtroMovimientosProvider = StateProvider<FiltroMovimientos>(
  (_) => FiltroMovimientos.todo,
);

/// Tras un cambio hecho desde Movimientos o Apuntar, pone al día las pantallas que guardan su
/// propia copia (el mes y el día a día). Inicio y Movimientos se actualizan solos.
Future<void> refrescarSecciones(WidgetRef ref) async {
  await Future.wait([
    ref.read(mesProvider.notifier).refrescar(),
    ref.read(comprasProvider.notifier).refrescar(),
  ]);
}
