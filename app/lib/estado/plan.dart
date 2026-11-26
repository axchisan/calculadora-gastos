import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Si lo que «sobra» resta también el día a día. Apagado por defecto: lo que sobra es lo que
/// queda después de sueldo, gastos fijos, deudas y créditos. Se recuerda en cada dispositivo.
final restarDiaADiaProvider = StateNotifierProvider<_RestarDiaADia, bool>(
  (ref) => _RestarDiaADia(),
);

class _RestarDiaADia extends StateNotifier<bool> {
  _RestarDiaADia() : super(false) {
    _cargar();
  }

  static const _clave = 'plan.restarDiaADia';

  Future<void> _cargar() async {
    try {
      final valor = (await SharedPreferences.getInstance()).getBool(_clave);
      if (valor != null && mounted) state = valor;
    } on Object {
      // Sin preferencias guardadas se queda el valor por defecto.
    }
  }

  Future<void> cambiar(bool valor) async {
    state = valor;
    try {
      await (await SharedPreferences.getInstance()).setBool(_clave, valor);
    } on Object {
      // Si no se puede guardar, vale para esta sesión.
    }
  }
}

/// Lo que sobra en un mes según la preferencia de restar o no el día a día.
double sobraSegun(MesPlan mes, {required bool restarDiaADia}) =>
    restarDiaADia ? mes.sobra : mes.sobra + mes.diario;
