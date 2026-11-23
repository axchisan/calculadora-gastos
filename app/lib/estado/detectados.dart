import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/extractos_compartidos.dart';
import '../datos/repositorio_detectados.dart';
import '../dominio/detectados.dart';
import '../dominio/modelos.dart';
import 'deudas.dart';
import 'proveedores.dart';

final repositorioDetectadosProvider = Provider<RepositorioDetectados>(
  (ref) => RepositorioDetectados(ref.watch(clienteApiProvider)),
);

final extractosCompartidosProvider = Provider<ExtractosCompartidos>(
  (ref) => const ExtractosCompartidos(),
);

/// Lo que llegó del banco y falta revisar, del más reciente al más viejo.
final detectadosProvider = FutureProvider<List<Detectado>>((ref) {
  ref.alActualizarse(['/api/detectados'], ref.invalidateSelf);
  final cambios = ref
      .read(clienteApiProvider)
      .cambiosLocales
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(cambios.cancel);
  return ref.watch(repositorioDetectadosProvider).pendientes();
});

/// Cuántos hay por revisar; 0 mientras carga o sin conexión.
final cuantosPorRevisarProvider = Provider<int>(
  (ref) => ref.watch(detectadosProvider).valueOrNull?.length ?? 0,
);

/// Un PDF compartido desde otra aplicación que la pantalla «Por revisar» debe importar.
final pdfPorImportarProvider = StateProvider<Uint8List?>((ref) => null);

/// Las deudas a las que se puede abonar (o de las que se puede cobrar).
final deudasParaAbonarProvider = FutureProvider<List<Deuda>>((ref) async {
  ref.alActualizarse(['/api/deudas'], ref.invalidateSelf);
  final todas = await ref
      .watch(repositorioDeudasProvider)
      .listar(soloActivas: true);
  return todas.where((d) => d.saldo > 0).toList();
});
