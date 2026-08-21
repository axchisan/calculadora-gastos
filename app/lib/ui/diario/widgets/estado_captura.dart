import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../datos/capturas_android.dart';
import '../../../estado/capturas.dart';
import 'guia_permiso.dart';

/// Enseña si la captura de pagos está funcionando de verdad, y qué falta si no.
///
/// Existe porque Android presenta como un único interruptor dos cosas que son distintas: que el
/// permiso esté concedido y que el servicio esté **enganchado**. Se puede tener lo primero sin
/// lo segundo —los fabricantes con gestión agresiva de batería matan el proceso y el sistema no
/// siempre lo vuelve a conectar— y en ese estado no llega ni una captura sin que nada avise.
///
/// Sin esta pantalla, averiguarlo exigía un cable y `adb`.
class EstadoDeLaCaptura extends ConsumerWidget {
  const EstadoDeLaCaptura({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capturaDisponibleProvider)) return const SizedBox.shrink();

    final estado = ref.watch(estadoCapturaProvider);

    return estado.maybeWhen(
      data: (datos) =>
          datos == null ? const SizedBox.shrink() : _Detalle(estado: datos),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Detalle extends ConsumerWidget {
  const _Detalle({required this.estado});

  final EstadoCaptura estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final capturas = ref.read(capturasAndroidProvider);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            (estado.todoListo
                    ? tema.colorScheme.primary
                    : tema.colorScheme.tertiary)
                .withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                estado.todoListo ? Icons.check_circle : Icons.error_outline,
                size: 20,
                color: estado.todoListo
                    ? tema.colorScheme.primary
                    : tema.colorScheme.tertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  estado.todoListo
                      ? 'Detectando pagos'
                      : 'La detección no está funcionando',
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _Punto(
            listo: estado.permiso,
            texto: 'Permiso para leer notificaciones',
          ),
          _Punto(
            listo: estado.enganchado,
            texto: estado.enganchado
                ? 'Servicio conectado desde '
                      '${Formato.fechaCorta(estado.conectadoDesde!)}'
                : 'Servicio conectado',
            // Es el punto que Android no enseña en ninguna parte y el que más falla.
            pista: estado.permiso && !estado.enganchado
                ? 'Android tiene el permiso concedido pero no ha enganchado el '
                      'servicio. Suele arreglarse reconectando.'
                : null,
          ),
          _Punto(
            listo: estado.avisosPermitidos,
            texto: 'Puede avisarte de cada compra',
          ),
          _Punto(
            listo: estado.bateriaLibre,
            texto: 'Sin restricción de batería',
            pista: estado.bateriaLibre
                ? null
                : 'Con la batería optimizada, el sistema puede matar el servicio '
                      'y dejar de entregarle notificaciones.',
          ),

          if (estado.capturas > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${estado.capturas} '
              '${estado.capturas == 1 ? 'captura guardada' : 'capturas guardadas'}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (!estado.enganchado)
                TextButton.icon(
                  onPressed: () async {
                    await capturas.reconectar();
                    // Android tarda un instante en enganchar; se relee después.
                    await Future<void>.delayed(const Duration(seconds: 2));
                    ref.invalidate(estadoCapturaProvider);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reconectar'),
                ),
              if (!estado.permiso || !estado.avisosPermitidos)
                TextButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const GuiaPermiso(),
                  ),
                  icon: const Icon(Icons.key, size: 18),
                  label: const Text('Permisos'),
                ),
              if (!estado.bateriaLibre)
                TextButton.icon(
                  onPressed: capturas.abrirAjustesDeBateria,
                  icon: const Icon(Icons.battery_saver, size: 18),
                  label: const Text('Batería'),
                ),
              TextButton.icon(
                onPressed: () async {
                  await capturas.probarAviso();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Aviso de prueba enviado. Si no aparece, el problema '
                        'está en los permisos de notificación.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Probar aviso'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.listo, required this.texto, this.pista});

  final bool listo;
  final String texto;
  final String? pista;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                listo ? Icons.check : Icons.close,
                size: 15,
                color: listo
                    ? tema.colorScheme.primary
                    : tema.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: tema.textTheme.bodySmall)),
            ],
          ),
          if (pista case final aclaracion?)
            Padding(
              padding: const EdgeInsets.only(left: 23, top: 2),
              child: Text(
                aclaracion,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
