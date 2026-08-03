import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/tema.dart';

/// Secciones principales de la aplicación.
enum Seccion {
  mes(
    '/',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
    'Mes',
  ),
  transporte(
    '/transporte',
    Icons.calendar_month_outlined,
    Icons.calendar_month,
    'Transporte',
  ),
  deudas('/deudas', Icons.credit_card_outlined, Icons.credit_card, 'Deudas'),
  ahorro('/ahorro', Icons.savings_outlined, Icons.savings, 'Ahorro'),
  graficas('/graficas', Icons.insights_outlined, Icons.insights, 'Gráficas');

  const Seccion(this.ruta, this.icono, this.iconoActivo, this.etiqueta);

  final String ruta;
  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
}

/// Estructura común: barra inferior en el móvil y carril lateral en pantallas anchas.
///
/// En el móvil la mano llega antes a la parte de abajo; en escritorio, una barra inferior a
/// lo ancho de la pantalla obligaría a recorrer una distancia absurda con el cursor.
class Navegacion extends StatelessWidget {
  const Navegacion({required this.hijo, super.key});

  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    final indice = _indiceActual(context);

    if (Pantalla.esMovil(context)) {
      return Scaffold(
        body: hijo,
        bottomNavigationBar: NavigationBar(
          selectedIndex: indice,
          onDestinationSelected: (i) => _ir(context, i),
          destinations: [
            for (final seccion in Seccion.values)
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
              for (final seccion in Seccion.values)
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
    for (var i = Seccion.values.length - 1; i >= 0; i--) {
      final seccion = Seccion.values[i];
      if (seccion != Seccion.mes && ruta.startsWith(seccion.ruta)) return i;
    }
    return 0;
  }

  static void _ir(BuildContext context, int indice) =>
      context.go(Seccion.values[indice].ruta);
}
