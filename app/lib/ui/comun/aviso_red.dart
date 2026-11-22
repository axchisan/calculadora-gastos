import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/red.dart';
import 'iconos.dart';

/// Franja discreta que avisa de que no hay conexión y de que lo visible es lo último guardado.
///
/// Sustituye a las pantallas de error: sin red, la app sigue enseñando lo que conoce y solo
/// deja claro que puede no estar al día.
class AvisoDeRed extends ConsumerWidget {
  const AvisoDeRed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final red = ref.watch(estadoRedProvider).valueOrNull;
    final sinConexion = red != null && !red.enLinea;
    final c = context.colores;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: !sinConexion
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: c.avisoFondo,
                padding: EdgeInsets.fromLTRB(
                  Espacio.lateral,
                  MediaQuery.paddingOf(context).top + 8,
                  Espacio.lateral,
                  8,
                ),
                child: Row(
                  children: [
                    Icon(Iconos.sinConexion, size: 16, color: c.aviso),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión desde las '
                        '${Formato.hora(red.sinConexionDesde!)} · ves lo último guardado',
                        style: Tipo.estilo(13, 600, color: c.aviso),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
