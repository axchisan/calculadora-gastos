import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/tema.dart';
import 'estado/autenticacion.dart';
import 'estado/capturas.dart';
import 'ui/ahorro/pantalla_ahorro.dart';
import 'ui/autenticacion/pantalla_acceso.dart';
import 'ui/cuenta/pantalla_cuenta.dart';
import 'ui/deudas/pantalla_deudas.dart';
import 'ui/diario/pantalla_diario.dart';
import 'ui/graficas/pantalla_graficas.dart';
import 'ui/inicio/pantalla_inicio.dart';
import 'ui/navegacion.dart';
import 'ui/plantillas/pantalla_plantillas.dart';
import 'ui/transporte/pantalla_transporte.dart';

/// Rutas de la aplicación.
class Rutas {
  const Rutas._();

  static const String inicio = '/';
  static const String diario = '/diario';
  static const String transporte = '/transporte';
  static const String deudas = '/deudas';
  static const String ahorro = '/ahorro';
  static const String graficas = '/graficas';
  static const String cuenta = '/cuenta';
  static const String plantillas = '/plantillas';
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

      // La cuenta queda fuera del armazón de navegación: se entra desde el menú y se vuelve,
      // no es una sección más entre las que se alterna.
      GoRoute(path: Rutas.cuenta, builder: (_, _) => const PantallaCuenta()),
      GoRoute(
        path: Rutas.plantillas,
        builder: (_, _) => const PantallaPlantillas(),
      ),

      ShellRoute(
        builder: (_, _, hijo) => Navegacion(hijo: hijo),
        routes: [
          GoRoute(
            path: Rutas.inicio,
            builder: (_, _) => const PantallaInicio(),
          ),
          GoRoute(
            path: Rutas.diario,
            builder: (_, _) => const PantallaDiario(),
          ),
          GoRoute(
            path: Rutas.transporte,
            builder: (_, _) => const PantallaTransporte(),
          ),
          GoRoute(
            path: Rutas.deudas,
            builder: (_, _) => const PantallaDeudas(),
          ),
          GoRoute(
            path: Rutas.ahorro,
            builder: (_, _) => const PantallaAhorro(),
          ),
          GoRoute(
            path: Rutas.graficas,
            builder: (_, _) => const PantallaGraficas(),
          ),
        ],
      ),
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
    final enrutador = ref.watch(enrutadorProvider);

    return MaterialApp.router(
      title: 'Calculadora de gastos',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.oscuro(),
      themeMode: ThemeMode.system,
      routerConfig: enrutador,
      // Envuelve toda la aplicación para poder saltar a la bandeja cuando se abre tocando el
      // aviso de una compra detectada, venga de un arranque en frío o de traerla al frente.
      builder: (_, hijo) => ProviderScope(
        overrides: [
          alAbrirDesdeElAvisoProvider.overrideWithValue(
            DestinoDeLaBandeja(() => enrutador.go(Rutas.diario)),
          ),
        ],
        child: SaltoALaBandeja(hijo: hijo ?? const SizedBox.shrink()),
      ),
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
