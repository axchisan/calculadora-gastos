import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/tema.dart';
import 'estado/apariencia.dart';
import 'estado/autenticacion.dart';
import 'estado/capturas.dart';
import 'estado/mes.dart';
import 'ui/ahorro/pantalla_ahorro.dart';
import 'ui/catalogo/pantalla_catalogo.dart';
import 'ui/autenticacion/pantalla_acceso.dart';
import 'ui/cuenta/pantalla_cuenta.dart';
import 'ui/deudas/pantalla_deudas.dart';
import 'ui/graficas/pantalla_graficas.dart';
import 'ui/inicio/pantalla_inicio.dart';
import 'ui/movimientos/pantalla_movimientos.dart';
import 'ui/mes/pantalla_mes.dart';
import 'ui/diario/pantalla_diario.dart';
import 'ui/ajustes/pantalla_ajustes.dart';
import 'ui/navegacion.dart';
import 'ui/plantillas/pantalla_plantillas.dart';
import 'ui/cuentas/pantalla_cuentas.dart';
import 'ui/sueldo/pantalla_sueldo.dart';
import 'ui/transporte/pantalla_transporte.dart';

/// Rutas de la aplicación.
class Rutas {
  const Rutas._();

  static const String inicio = '/';
  static const String movimientos = '/movimientos';

  /// Sueldo, ingresos y gastos fijos del mes, con el cierre: la pantalla del mes de antes.
  static const String detalleMes = '/movimientos/mes';

  /// Compras del día a día, tarjetas y la bandeja de compras detectadas.
  static const String diario = '/movimientos/dia';
  static const String deudas = '/deudas';
  static const String analisis = '/analisis';
  static const String ajustes = '/ajustes';
  static const String transporte = '/transporte';
  static const String ahorro = '/ahorro';
  static const String cuenta = '/cuenta';
  static const String plantillas = '/plantillas';
  static const String cuentas = '/cuentas';
  static const String sueldo = '/sueldo';
  static const String acceso = '/acceso';
  static const String cargando = '/cargando';
  static const String catalogo = '/catalogo';
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
      GoRoute(path: Rutas.cuentas, builder: (_, _) => const PantallaCuentas()),
      GoRoute(path: Rutas.sueldo, builder: (_, _) => const PantallaSueldo()),
      GoRoute(path: Rutas.ajustes, builder: (_, _) => const PantallaAjustes()),
      // Secciones opcionales: se encienden en Ajustes y se abren desde Inicio.
      GoRoute(
        path: Rutas.transporte,
        builder: (_, _) => const PantallaTransporte(),
      ),
      GoRoute(path: Rutas.ahorro, builder: (_, _) => const PantallaAhorro()),
      if (PantallaCatalogo.habilitado)
        GoRoute(
          path: Rutas.catalogo,
          builder: (_, _) => const PantallaCatalogo(),
        ),

      ShellRoute(
        builder: (_, _, hijo) => Navegacion(hijo: hijo),
        routes: [
          GoRoute(
            path: Rutas.inicio,
            builder: (_, _) => const PantallaInicio(),
          ),
          GoRoute(
            path: Rutas.movimientos,
            builder: (_, _) => const PantallaMovimientos(),
            routes: [
              GoRoute(path: 'mes', builder: (_, _) => const PantallaMes()),
              GoRoute(path: 'dia', builder: (_, _) => const PantallaDiario()),
            ],
          ),
          GoRoute(
            path: Rutas.deudas,
            builder: (_, _) => const PantallaDeudas(),
          ),
          GoRoute(
            path: Rutas.analisis,
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
    // Deja anotado el mes elegido para volver a él en la próxima apertura.
    ref.watch(recordarPeriodoProvider);

    return MaterialApp.router(
      title: 'Calculadora de gastos',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.oscuro(),
      themeMode: ref.watch(temaProvider),
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
