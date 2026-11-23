import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/ingesta_sms.dart';
import '../datos/repositorio_ingesta.dart';
import 'proveedores.dart';

final ingestaSmsProvider = Provider<IngestaSms>((ref) => const IngestaSms());

final repositorioIngestaProvider = Provider<RepositorioIngesta>(
  (ref) => RepositorioIngesta(ref.watch(clienteApiProvider)),
);

/// Cómo está la lectura de SMS en este teléfono; null fuera de Android.
final estadoSmsProvider = FutureProvider<EstadoSms?>(
  (ref) => ref.watch(ingestaSmsProvider).estado(),
);

/// Las claves de ingesta activas (teléfono, Gmail).
final clavesIngestaProvider = FutureProvider<List<ClaveIngesta>>((ref) {
  ref.alActualizarse(['/api/ingesta'], ref.invalidateSelf);
  return ref.watch(repositorioIngestaProvider).claves();
});
