import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/tema.dart';
import '../estado/proveedores.dart';
import '../estado/red.dart';
import 'comun/aviso_red.dart';
import 'comun/iconos.dart';

/// Las cuatro pestañas del rediseño v2. Transporte y Ahorro pasaron a ser secciones
/// opcionales que se encienden en Ajustes; Mi sueldo, Mis cuentas y los gastos fijos se abren
/// desde Inicio o desde Ajustes.
enum SeccionPrincipal {
  inicio('/', Iconos.inicio, Iconos.inicioActivo, 'Inicio'),
  movimientos(
    '/movimientos',
    Iconos.movimientos,
    Iconos.movimientosActivo,
    'Movimientos',
  ),
  deudas('/deudas', Iconos.deudas, Iconos.deudasActivo, 'Deudas'),
  analisis('/analisis', Iconos.analisis, Iconos.analisisActivo, 'Análisis');

  const SeccionPrincipal(
    this.ruta,
    this.icono,
    this.iconoActivo,
    this.etiqueta,
  );

  final String ruta;
  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
}

/// Estructura común: barra inferior en el móvil y carril lateral en pantallas anchas.
///
/// En el móvil la mano llega antes a la parte de abajo; en escritorio, una barra inferior a
/// lo ancho de la pantalla obligaría a recorrer una distancia absurda con el cursor.
class Navegacion extends ConsumerStatefulWidget {
  const Navegacion({required this.hijo, super.key});

  final Widget hijo;

  @override
  ConsumerState<Navegacion> createState() => _EstadoNavegacion();
}

class _EstadoNavegacion extends ConsumerState<Navegacion> {
  late final AppLifecycleListener _ciclo;
  DateTime _ultimaRevision = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Al volver a la app tras un rato fuera, lo guardado puede haber cambiado en otro
    // dispositivo: se revisa todo por detrás mientras se enseña lo que ya había.
    // Lo que quedó apuntado sin conexión en una sesión anterior se envía al abrir.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(clienteApiProvider).iniciarCola(),
    );
    _ciclo = AppLifecycleListener(
      onResume: () {
        final ahora = DateTime.now();
        if (ahora.difference(_ultimaRevision) > const Duration(minutes: 2)) {
          _ultimaRevision = ahora;
          ref.read(clienteApiProvider).revisarTodo();
        }
      },
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(precargaProvider);
    final indice = _indiceActual(context);
    final hijo = Column(
      children: [
        const AvisoDeRed(),
        // Cada pestaña con su propio gestor de avisos: así un aviso con «Deshacer» sale en la
        // pantalla de la pestaña, encima de la barra, y aparta su botón «+» en vez de taparlo.
        Expanded(child: ScaffoldMessenger(child: widget.hijo)),
      ],
    );

    if (Pantalla.esMovil(context)) {
      return Scaffold(
        body: hijo,
        bottomNavigationBar: NavigationBar(
          selectedIndex: indice,
          onDestinationSelected: (i) => _ir(context, i),
          destinations: [
            for (final seccion in SeccionPrincipal.values)
              NavigationDestination(
                icon: Icon(seccion.icono),
                selectedIcon: Icon(seccion.iconoActivo),
                label: seccion.etiqueta,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: indice,
            onDestinationSelected: (i) => _ir(context, i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final seccion in SeccionPrincipal.values)
                NavigationRailDestination(
                  icon: Icon(seccion.icono),
                  selectedIcon: Icon(seccion.iconoActivo),
                  label: Text(seccion.etiqueta),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: hijo),
        ],
      ),
    );
  }

  /// Sección activa según la ruta.
  ///
  /// Se compara por prefijo para que las pantallas de detalle mantengan resaltada su sección.
  static int _indiceActual(BuildContext context) {
    final ruta = GoRouterState.of(context).matchedLocation;
    for (var i = SeccionPrincipal.values.length - 1; i >= 0; i--) {
      final seccion = SeccionPrincipal.values[i];
      if (seccion != SeccionPrincipal.inicio && ruta.startsWith(seccion.ruta)) {
        return i;
      }
    }
    return 0;
  }

  static void _ir(BuildContext context, int indice) =>
      context.go(SeccionPrincipal.values[indice].ruta);
}
