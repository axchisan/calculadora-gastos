import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/almacen_sesion.dart';
import '../datos/cliente_api.dart';
import 'proveedores.dart';

/// Situación de la sesión del usuario.
sealed class EstadoSesion {
  const EstadoSesion();
}

/// Aún se está leyendo la sesión guardada; se muestra la pantalla de carga.
class SesionComprobando extends EstadoSesion {
  const SesionComprobando();
}

/// No hay sesión: toca iniciar sesión o registrarse.
class SesionCerrada extends EstadoSesion {
  const SesionCerrada();
}

class SesionAbierta extends EstadoSesion {
  const SesionAbierta(this.sesion);

  final SesionGuardada sesion;
}

/// Gestiona el ciclo de vida de la sesión.
class ControladorSesion extends StateNotifier<EstadoSesion> {
  ControladorSesion(this._cliente) : super(const SesionComprobando()) {
    _restaurar();
  }

  final ClienteApi _cliente;

  /// Recupera la sesión guardada al abrir la aplicación.
  ///
  /// No se comprueba contra el servidor: si el token caducó, la primera petición lo renovará
  /// sola. Consultar aquí retrasaría el arranque por el tiempo del arranque en frío de Lambda.
  Future<void> _restaurar() async {
    final sesion = await _cliente.cargarSesion();
    state = sesion == null ? const SesionCerrada() : SesionAbierta(sesion);
  }

  Future<void> registrar({
    required String email,
    required String password,
    required String nombre,
  }) async {
    final respuesta = await _cliente.publicar<Map<String, dynamic>>(
      '/api/auth/registro',
      cuerpo: {
        'email': email.trim(),
        'password': password,
        'nombre': nombre.trim(),
      },
    );
    await _guardar(respuesta);
  }

  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final respuesta = await _cliente.publicar<Map<String, dynamic>>(
      '/api/auth/login',
      cuerpo: {'email': email.trim(), 'password': password},
    );
    await _guardar(respuesta);
  }

  Future<void> cerrarSesion() async {
    final refresco = _cliente.sesion?.refreshToken;
    // El estado local se limpia pase lo que pase: si la petición falla por falta de red, el
    // usuario igualmente espera haber salido.
    try {
      if (refresco != null) {
        await _cliente.publicar<void>(
          '/api/auth/logout',
          cuerpo: {'refreshToken': refresco},
        );
      }
    } on ErrorApi {
      // Sin efecto sobre el cierre local.
    } finally {
      await _cliente.cerrarSesion();
      state = const SesionCerrada();
    }
  }

  Future<void> _guardar(Map<String, dynamic> respuesta) async {
    final sesion = SesionGuardada.deRespuesta(respuesta);
    await _cliente.establecerSesion(sesion);
    state = SesionAbierta(sesion);
  }
}

final sesionProvider = StateNotifierProvider<ControladorSesion, EstadoSesion>(
  (ref) => ControladorSesion(ref.watch(clienteApiProvider)),
);

/// Atajo para saber si hay sesión abierta.
final haySesionProvider = Provider<bool>(
  (ref) => ref.watch(sesionProvider) is SesionAbierta,
);
