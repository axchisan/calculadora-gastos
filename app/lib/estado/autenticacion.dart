import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/almacen_sesion.dart';
import '../datos/cache_local.dart';
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
  ControladorSesion(this._cliente, this._cache)
    : super(const SesionComprobando()) {
    _restaurar();
  }

  final ClienteApi _cliente;
  final CacheLocal _cache;

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
      // El caché guarda cifras de la cuenta: no debe sobrevivir al cierre de sesión.
      await _cache.limpiar();
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
  (ref) => ControladorSesion(
    ref.watch(clienteApiProvider),
    ref.watch(cacheProvider),
  ),
);

/// Atajo para saber si hay sesión abierta.
final haySesionProvider = Provider<bool>(
  (ref) => ref.watch(sesionProvider) is SesionAbierta,
);

/// Indica si el servidor admite cuentas nuevas.
///
/// La aplicación es de uso personal: el registro solo está abierto mientras no exista ninguna
/// cuenta. Consultarlo permite ocultar la opción de crear cuenta en lugar de ofrecerla para
/// que acabe en un error.
///
/// Ante un fallo de red se asume cerrado, que es lo habitual: mostrar el registro cuando no
/// procede confunde más que ocultarlo de menos.
final registroAbiertoProvider = FutureProvider<bool>((ref) async {
  try {
    final respuesta = await ref
        .watch(clienteApiProvider)
        .obtener<Map<String, dynamic>>('/api/auth/registro-abierto');
    return respuesta['abierto'] as bool? ?? false;
  } on ErrorApi {
    return false;
  }
});

/// Cambios sobre las credenciales de la cuenta.
class ControladorCuenta {
  const ControladorCuenta(this._cliente);

  final ClienteApi _cliente;

  /// Cambia la contraseña. El servidor revoca el resto de sesiones y devuelve una nueva.
  Future<SesionGuardada> cambiarPassword({
    required String actual,
    required String nueva,
  }) async {
    final respuesta = await _cliente.modificar<Map<String, dynamic>>(
      '/api/auth/password',
      cuerpo: {'passwordActual': actual, 'passwordNueva': nueva},
    );
    return _guardar(respuesta);
  }

  Future<SesionGuardada> cambiarEmail({
    required String password,
    required String emailNuevo,
  }) async {
    final respuesta = await _cliente.modificar<Map<String, dynamic>>(
      '/api/auth/email',
      cuerpo: {'password': password, 'emailNuevo': emailNuevo.trim()},
    );
    return _guardar(respuesta);
  }

  Future<void> cambiarNombre(String nombre) =>
      _cliente.modificar<Map<String, dynamic>>(
        '/api/auth/nombre',
        cuerpo: {'nombre': nombre.trim()},
      );

  Future<SesionGuardada> _guardar(Map<String, dynamic> respuesta) async {
    final sesion = SesionGuardada.deRespuesta(respuesta);
    await _cliente.establecerSesion(sesion);
    return sesion;
  }
}

final cuentaProvider = Provider<ControladorCuenta>(
  (ref) => ControladorCuenta(ref.watch(clienteApiProvider)),
);
