import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/almacen_sesion.dart';
import '../datos/cache_local.dart';
import '../datos/cliente_api.dart';

/// Caché local de las últimas respuestas.
///
/// Se sobrescribe en `main` con la instancia ya abierta, porque abrirla es asíncrono y los
/// proveedores síncronos no pueden esperar.
final cacheProvider = Provider<CacheLocal>(
  (ref) => throw StateError('El caché debe inicializarse en main'),
);

/// Almacén seguro de la sesión.
final almacenSesionProvider = Provider<AlmacenSesion>((ref) => AlmacenSesion());

/// Cliente HTTP compartido por toda la aplicación.
///
/// Es único a propósito: mantiene el token en memoria y coordina la renovación para que dos
/// peticiones simultáneas no lancen dos refrescos y se invaliden entre sí.
final clienteApiProvider = Provider<ClienteApi>(
  (ref) => ClienteApi(ref.watch(almacenSesionProvider)),
);
