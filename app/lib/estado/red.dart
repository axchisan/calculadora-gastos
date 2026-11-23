import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cliente_api.dart';
import 'compras.dart';
import 'creditos.dart';
import 'cuentas.dart';
import 'deudas.dart';
import 'graficas.dart';
import 'inicio.dart';
import 'mes.dart';
import 'proveedores.dart';

/// Si hay conexión con el servidor. Empieza con el estado actual y sigue sus cambios.
final estadoRedProvider = StreamProvider<EstadoRed>((ref) async* {
  final api = ref.watch(clienteApiProvider);
  yield api.red;
  yield* api.cambiosDeRed;
});

/// Pone a cargar todas las secciones a la vez en cuanto hay sesión.
///
/// Antes cada pestaña pedía sus datos al abrirla, y con Lambda en frío eso era una espera por
/// pestaña. Así, al tocar Deudas o Diario ya están listas: desde la copia local al instante y
/// desde el servidor en cuanto responde.
final precargaProvider = Provider<void>((ref) {
  ref
    ..watch(mesProvider)
    ..watch(comprasProvider)
    ..watch(deudasProvider)
    ..watch(creditosProvider)
    ..watch(cuentasProvider)
    ..watch(fuentesIngresoProvider)
    ..watch(tarjetasProvider)
    ..watch(evolucionProvider)
    ..watch(inicioProvider);
});
