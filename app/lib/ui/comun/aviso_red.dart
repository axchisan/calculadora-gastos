import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../estado/proveedores.dart';
import '../../estado/red.dart';
import 'componentes.dart';
import 'iconos.dart';

/// Franja discreta con el estado de la conexión y de lo apuntado sin ella.
///
/// Sustituye a las pantallas de error: sin red, la app sigue enseñando lo que conoce y deja
/// claro que puede no estar al día, cuántos cambios esperan a subirse y si alguno falló.
class AvisoDeRed extends ConsumerWidget {
  const AvisoDeRed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final red = ref.watch(estadoRedProvider).valueOrNull;
    final c = context.colores;
    final contenido = red == null ? null : _contenido(red);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: contenido == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              button: contenido.alTocar,
              child: Material(
                color: switch (contenido.tono) {
                  Tono.negativo => c.negativoFondo,
                  Tono.aviso => c.avisoFondo,
                  _ => c.superficie2,
                },
                child: InkWell(
                  onTap: contenido.alTocar ? () => _revisar(context) : null,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      Espacio.lateral,
                      MediaQuery.paddingOf(context).top + 8,
                      Espacio.lateral,
                      8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          contenido.icono,
                          size: 16,
                          color: contenido.color(c),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            contenido.texto,
                            style: Tipo.estilo(
                              13,
                              600,
                              color: contenido.color(c),
                            ),
                          ),
                        ),
                        if (contenido.alTocar)
                          Icon(
                            Iconos.entrar,
                            size: 14,
                            color: contenido.color(c),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  static _Contenido? _contenido(EstadoRed red) {
    String cambios(int n) => n == 1 ? '1 cambio' : '$n cambios';

    if (red.conError > 0) {
      return _Contenido(
        tono: Tono.negativo,
        icono: Iconos.atencion,
        texto: '${cambios(red.conError)} no se pudo subir · Revisar',
        alTocar: true,
      );
    }
    if (!red.enLinea) {
      final porSubir = red.porSubir > 0
          ? ' · ${cambios(red.porSubir)} por subir'
          : ' · ves lo último guardado';
      return _Contenido(
        tono: Tono.aviso,
        icono: Iconos.sinConexion,
        texto:
            'Sin conexión desde las ${Formato.hora(red.sinConexionDesde!)}$porSubir',
      );
    }
    if (red.porSubir > 0) {
      return _Contenido(
        tono: Tono.suave,
        icono: Iconos.deshacer,
        texto: 'Subiendo ${cambios(red.porSubir)}…',
      );
    }
    return null;
  }

  Future<void> _revisar(BuildContext context) => abrirHoja<void>(
    context,
    titulo: 'Cambios sin subir',
    subtitulo:
        'El servidor rechazó estos cambios apuntados sin conexión. Puedes intentarlo de '
        'nuevo o descartarlos.',
    contenido: (_) => const _ListaPendientes(),
  );
}

class _Contenido {
  const _Contenido({
    required this.tono,
    required this.icono,
    required this.texto,
    this.alTocar = false,
  });

  final Tono tono;
  final IconData icono;
  final String texto;
  final bool alTocar;

  Color color(Colores c) => switch (tono) {
    Tono.negativo => c.negativo,
    Tono.aviso => c.aviso,
    _ => c.tinta2,
  };
}

class _ListaPendientes extends ConsumerWidget {
  const _ListaPendientes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se observa el estado para repintar la lista al reintentar o descartar.
    ref.watch(estadoRedProvider);
    final api = ref.read(clienteApiProvider);
    final fallidas = api.pendientes.where((o) => o.error != null).toList();

    if (fallidas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No queda nada por revisar.'),
      );
    }

    return Panel.lista(
      filas: [
        for (final o in fallidas)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.descripcion,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  o.error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colores.negativo,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => api.descartar(o.id),
                      child: Text(
                        'Descartar',
                        style: TextStyle(color: context.colores.negativo),
                      ),
                    ),
                    TextButton(
                      onPressed: () => api.reintentar(o.id),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
