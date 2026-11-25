import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/repositorio_plan.dart';
import '../dominio/plan.dart';
import 'proveedores.dart';

final repositorioPlanProvider = Provider<RepositorioPlan>(
  (ref) => RepositorioPlan(ref.watch(clienteApiProvider)),
);

/// El plan depende de casi todo (sueldo, gastos, deudas, créditos, metas): se vuelve a pedir
/// tras cualquier cambio hecho en la app.
final planProvider = FutureProvider<Plan>((ref) {
  ref.alActualizarse([
    '/api/plan',
    '/api/meses',
    '/api/gastos',
    '/api/sueldo',
    '/api/deudas',
    '/api/creditos',
    '/api/ahorro',
    '/api/plantillas',
  ], ref.invalidateSelf);
  final cambios = ref
      .read(clienteApiProvider)
      .cambiosLocales
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(cambios.cancel);
  return ref.watch(repositorioPlanProvider).obtener();
});
