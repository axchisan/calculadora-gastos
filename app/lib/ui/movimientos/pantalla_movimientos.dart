import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/tema.dart';
import '../diario/pantalla_diario.dart';
import '../mes/pantalla_mes.dart';

/// Lo que entra y sale del mes.
///
/// Mientras llega la línea de tiempo unificada (fase 5 del rediseño), junta las dos pantallas
/// que ya existían: el mes (sueldo, ingresos y gastos fijos) y las compras del día a día. Cuál
/// se ve lo decide la ruta, para que el aviso de una compra detectada pueda abrir directamente
/// el día a día.
class PantallaMovimientos extends StatelessWidget {
  const PantallaMovimientos({required this.verDiario, super.key});

  final bool verDiario;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lateral,
              Espacio.s,
              Espacio.lateral,
              0,
            ),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(value: false, label: Text('Mes')),
                ButtonSegment(value: true, label: Text('Día a día')),
              ],
              selected: {verDiario},
              onSelectionChanged: (s) =>
                  context.go(s.first ? Rutas.diario : Rutas.movimientos),
            ),
          ),
        ),
        // Las dos pantallas traen su propia barra superior; el margen del sistema ya lo puso
        // el selector de arriba.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: verDiario ? const PantallaDiario() : const PantallaMes(),
          ),
        ),
      ],
    );
  }
}
