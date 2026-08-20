import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../estado/capturas.dart';

/// Explica cómo desbloquear el acceso a las notificaciones.
///
/// Android 13 introdujo los «ajustes restringidos»: si la aplicación se instaló desde un APK y
/// no desde una tienda, el interruptor del acceso a notificaciones aparece apagado y no se deja
/// tocar. El sistema muestra «Controlled by restricted setting» y un aviso de que el permiso
/// puede poner en riesgo la información financiera, pero **no dice qué hacer**.
///
/// Lo que hace falta está escondido en el menú de tres puntos de la ficha de la aplicación. Sin
/// que alguien lo cuente, no hay forma razonable de dar con ello, y por eso esta pantalla
/// existe.
class GuiaPermiso extends ConsumerWidget {
  const GuiaPermiso({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final capturas = ref.watch(capturasAndroidProvider);

    // Con la aplicación instalada desde una tienda no hay restricción y sobra el rodeo.
    final esLateral = ref
        .watch(instalacionLateralProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detectar pagos', style: tema.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Para leer las notificaciones de pago hace falta un permiso que Android '
              'no concede con un botón.',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            if (esLateral) ...[
              const SizedBox(height: 20),
              _Aviso(
                texto:
                    'Como la app se instaló desde un archivo y no desde Play Store, Android '
                    'marca este permiso como restringido: verás el interruptor apagado y sin '
                    'poder tocarlo. Hay que desbloquearlo primero.',
              ),
              const SizedBox(height: 20),
              _Paso(
                numero: 1,
                titulo: 'Desbloquea los ajustes restringidos',
                detalle:
                    'En la ficha de la app, toca el menú de tres puntos de arriba a la '
                    'derecha y elige «Permitir ajustes restringidos».',
                accion: 'Abrir la ficha de la app',
                alPulsar: capturas.abrirInfoDeLaApp,
              ),
              const SizedBox(height: 16),
              _Paso(
                numero: 2,
                titulo: 'Activa el acceso a notificaciones',
                detalle:
                    'Busca «Mis gastos» en la lista y enciende el interruptor, que ya se '
                    'dejará tocar.',
                accion: 'Abrir acceso a notificaciones',
                alPulsar: capturas.abrirAjustes,
              ),
              const SizedBox(height: 20),
              _Nota(
                texto:
                    'Si la opción de los tres puntos no aparece, entra una vez en el acceso '
                    'a notificaciones e intenta encender el interruptor. Al rechazarlo, '
                    'Android habilita esa opción en el menú.',
              ),
            ] else ...[
              const SizedBox(height: 20),
              _Paso(
                numero: 1,
                titulo: 'Activa el acceso a notificaciones',
                detalle:
                    'Busca «Mis gastos» en la lista y enciende el interruptor.',
                accion: 'Abrir acceso a notificaciones',
                alPulsar: capturas.abrirAjustes,
              ),
            ],

            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                // De paso se pide el permiso de publicar avisos: sin él la app detectaría las
                // compras pero no podría avisar, que es lo que ahorra tener que abrirla.
                await capturas.pedirPermisoDeAvisos();
                // Al volver de Ajustes el permiso de notificaciones puede haber cambiado.
                ref.invalidate(permisoCapturaProvider);
                if (context.mounted) Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Ya está, comprobar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.titulo,
    required this.detalle,
    required this.accion,
    required this.alPulsar,
  });

  final int numero;
  final String titulo;
  final String detalle;
  final String accion;
  final Future<void> Function() alPulsar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tema.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: tema.textTheme.labelMedium?.copyWith(
              color: tema.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: tema.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detalle,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: alPulsar,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(accion),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: tema.colorScheme.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lightbulb_outline,
          size: 16,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
