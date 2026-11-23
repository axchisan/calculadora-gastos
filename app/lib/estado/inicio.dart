import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/repositorio_inicio.dart';
import '../dominio/inicio.dart';
import 'proveedores.dart';

final repositorioInicioProvider = Provider<RepositorioInicio>(
  (ref) => RepositorioInicio(ref.watch(clienteApiProvider)),
);

/// Lo de la pantalla de Inicio. Junta datos de casi todas las secciones, así que se vuelve a
/// pedir también cuando cambia cualquiera de ellas.
final inicioProvider = FutureProvider<DatosInicio>((ref) {
  ref.alActualizarse([
    '/api/inicio',
    '/api/meses',
    '/api/gastos',
    '/api/cuentas',
    '/api/sueldo',
    '/api/deudas',
    '/api/creditos',
  ], ref.invalidateSelf);
  final cambios = ref
      .read(clienteApiProvider)
      .cambiosLocales
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(cambios.cancel);
  return ref.watch(repositorioInicioProvider).obtener();
});
