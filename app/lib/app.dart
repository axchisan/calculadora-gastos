import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/tema.dart';
import 'estado/autenticacion.dart';
import 'ui/autenticacion/pantalla_acceso.dart';
import 'ui/inicio/pantalla_inicio.dart';

/// Rutas de la aplicación.
class Rutas {
  const Rutas._();

  static const String inicio = '/';
  static const String acceso = '/acceso';
  static const String cargando = '/cargando';
}

/// Enrutador que decide a dónde llevar según el estado de la sesión.
final enrutadorProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Rutas.cargando,
    refreshListenable: _EscuchaSesion(ref),
    redirect: (context, estado) {
      final sesion = ref.read(sesionProvider);
      final ruta = estado.matchedLocation;

      return switch (sesion) {
        SesionComprobando() => ruta == Rutas.cargando ? null : Rutas.cargando,
        SesionCerrada() => ruta == Rutas.acceso ? null : Rutas.acceso,
        // Al abrir sesión, quien estuviera en el acceso o en la carga pasa al inicio.
        SesionAbierta() =>
          (ruta == Rutas.acceso || ruta == Rutas.cargando)
              ? Rutas.inicio
              : null,
      };
    },
    routes: [
      GoRoute(
        path: Rutas.cargando,
        builder: (_, _) => const _PantallaCargando(),
      ),
      GoRoute(path: Rutas.acceso, builder: (_, _) => const PantallaAcceso()),
      GoRoute(path: Rutas.inicio, builder: (_, _) => const PantallaInicio()),
    ],
  );
});

/// Puente entre Riverpod y GoRouter: notifica al enrutador cuando cambia la sesión.
class _EscuchaSesion extends ChangeNotifier {
  _EscuchaSesion(Ref ref) {
    ref.listen(sesionProvider, (_, _) => notifyListeners());
  }
}

class AplicacionGastos extends ConsumerWidget {
  const AplicacionGastos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Calculadora de gastos',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.oscuro(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(enrutadorProvider),
    );
  }
}

class _PantallaCargando extends StatelessWidget {
  const _PantallaCargando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
