import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las dos formas de mirar un mes.
enum ModoVista {
  /// Cuenta solo lo efectivamente pagado. Responde a «¿cuánto tengo ahora mismo?».
  real('Real', 'Lo que llevas pagado'),

  /// Cuenta todo lo que tiene destino, se haya pagado o no. Responde a «¿cuánto de mi sueldo
  /// ya está comprometido?», que es la pregunta útil para planificar un mes que aún no ha
  /// empezado, donde no hay ningún pago hecho y las cifras de lo pagado son todas cero.
  estimacion('Estimación', 'Lo que tienes comprometido');

  const ModoVista(this.etiqueta, this.descripcion);

  final String etiqueta;
  final String descripcion;

  ModoVista get contrario => this == real ? estimacion : real;
}

/// Modo activo, recordado entre sesiones.
///
/// Se guarda porque es una preferencia de cómo se quiere leer la aplicación, no una acción
/// puntual: quien planifica con antelación abrirá siempre en estimación.
class ControladorModoVista extends StateNotifier<ModoVista> {
  ControladorModoVista() : super(ModoVista.real) {
    _restaurar();
  }

  static const String _clave = 'modoVista';

  Future<void> _restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);
    if (guardado == ModoVista.estimacion.name) {
      state = ModoVista.estimacion;
    }
  }

  Future<void> alternar() async {
    state = state.contrario;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, state.name);
  }
}

final modoVistaProvider =
    StateNotifierProvider<ControladorModoVista, ModoVista>(
      (ref) => ControladorModoVista(),
    );
