import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../datos/cliente_api.dart';

/// Elementos que el usuario acaba de borrar y aún puede recuperar.
///
/// Las listas los esconden mientras dura el aviso de «Deshacer». El borrado en el servidor
/// solo ocurre cuando el aviso se va sin que nadie lo toque.
final ocultosProvider = StateProvider<Set<String>>((_) => const {});

/// Cuánto tiempo hay para arrepentirse.
const duracionDeshacer = Duration(seconds: 5);

/// Borra con red de seguridad: esconde el elemento al instante y ofrece deshacer.
///
/// Nace de un caso real: deslizar un ingreso lo borraba en el acto, y un mal gesto al hacer
/// scroll se llevó dos ingresos que hubo que reconstruir a mano con los extractos del banco.
///
/// El borrado se aplaza en lugar de recrear el elemento al deshacer, porque recrearlo pierde lo
/// que cuelga de él (los abonos de una deuda, el gasto fijo del que salió un gasto) y le da un
/// identificador nuevo. Si la app se cierra antes de que venza el aviso, el elemento sigue ahí:
/// ante la duda, es preferible no borrar.
///
/// [borrar] debe capturar lo que necesite antes de llamar a esta función: cuando venza el aviso,
/// la pantalla que la llamó puede haberse cerrado ya.
Future<void> borrarConDeshacer(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String mensaje,
  required Future<void> Function() borrar,
}) async {
  final mensajero = ScaffoldMessenger.of(context);
  final ocultos = ref.read(ocultosProvider.notifier);

  ocultos.update((actual) => {...actual, id});

  // Si había otro aviso pendiente, se cierra y ese borrado se confirma: solo se puede deshacer
  // lo último, como en cualquier editor.
  mensajero.hideCurrentSnackBar();
  final motivo = await mensajero
      .showSnackBar(
        SnackBar(
          content: Text(mensaje),
          duration: duracionDeshacer,
          // Con acción, el aviso se quedaría en pantalla hasta tocarlo: aquí tiene que irse
          // solo para que el borrado llegue a ocurrir.
          persist: false,
          action: SnackBarAction(label: 'Deshacer', onPressed: () {}),
        ),
      )
      .closed;

  if (motivo == SnackBarClosedReason.action) {
    ocultos.update((actual) => actual.difference({id}));
    return;
  }

  try {
    await borrar();
  } on ErrorApi catch (e) {
    mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
  } finally {
    ocultos.update((actual) => actual.difference({id}));
  }
}

/// Atajo para filtrar una lista quitando lo que está pendiente de borrar.
extension SinOcultos<T> on Iterable<T> {
  List<T> sinOcultos(Set<String> ocultos, String Function(T) id) =>
      where((e) => !ocultos.contains(id(e))).toList();
}
