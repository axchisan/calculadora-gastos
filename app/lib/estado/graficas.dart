import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio/modelos.dart';
import 'mes.dart';

/// Serie histórica de los últimos meses, para las gráficas de evolución.
///
/// Se piden doce meses hacia atrás: es el horizonte donde se aprecian las tendencias sin que
/// la gráfica se vuelva ilegible en el móvil.
final evolucionProvider = FutureProvider<List<ResumenMensual>>((ref) async {
  // Depender del mes hace que la serie se refresque al registrar cualquier cambio.
  ref.watch(mesProvider);

  final desde = DateTime.now().subtract(const Duration(days: 365));
  return ref
      .watch(repositorioMesesProvider)
      .evolucion(anio: desde.year, mes: desde.month);
});
