import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../datos/cliente_api.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/capturas.dart';
import '../../../estado/compras.dart';
import '../../../estado/mes.dart';
import 'formulario_compra.dart';

/// Los pagos que el teléfono capturó y esperan confirmación.
///
/// No se registran solos a propósito. Un importe mal reconocido metido directamente en el
/// presupuesto haría perder la confianza en las cifras, que es lo único que esta aplicación
/// tiene que ofrecer. Confirmar cuesta un toque y el usuario ve lo que entra.
class BandejaCapturas extends ConsumerWidget {
  const BandejaCapturas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capturaDisponibleProvider)) return const SizedBox.shrink();

    final pendientes = ref.watch(pagosPendientesProvider);

    return pendientes.maybeWhen(
      data: (lista) {
        if (lista.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Encabezado(cantidad: lista.length),
            const SizedBox(height: 8),
            for (final pago in lista) ...[
              _TarjetaPago(pendiente: pago),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
          ],
        );
      },
      // Un fallo leyendo las capturas no debe tapar la lista de compras, que es lo principal.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.notifications_active_outlined,
          size: 18,
          color: tema.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          cantidad == 1
              ? 'Un pago detectado en el teléfono'
              : '$cantidad pagos detectados en el teléfono',
          style: tema.textTheme.titleSmall?.copyWith(
            color: tema.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TarjetaPago extends ConsumerWidget {
  const _TarjetaPago({required this.pendiente});

  final PagoPendiente pendiente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final pago = pendiente.pago;

    return Card(
      margin: EdgeInsets.zero,
      color: tema.colorScheme.primary.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pendiente.descripcionSugerida,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formato.dinero(pago.monto),
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _detalle(),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            if (pendiente.faltaIdentificarTarjeta) ...[
              const SizedBox(height: 8),
              _AvisoTarjetaSinReconocer(pendiente: pendiente),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _descartar(ref),
                  child: const Text('Descartar'),
                ),
                const SizedBox(width: 8),
                // Confirmar es lo que se viene a hacer aquí, así que va en botón lleno y no
                // tonal: sobre una tarjeta ya teñida de color primario, el tonal se confunde
                // con el fondo.
                FilledButton(
                  onPressed: () => _registrar(context, ref),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _detalle() {
    final pago = pendiente.pago;
    final partes = <String>[
      Formato.fechaCorta(pago.instante),
      if (pendiente.tarjeta case final tarjeta?)
        tarjeta.esDeCredito
            ? '${tarjeta.nombre} · crédito'
            : '${tarjeta.nombre} · débito'
      else if (pago.apodoTarjeta case final apodo?)
        apodo
      else if (pago.ultimos4 case final digitos?)
        'terminada en $digitos',
    ];
    return partes.join(' · ');
  }

  Future<void> _descartar(WidgetRef ref) =>
      ref.read(descartarCapturasProvider)(pendiente.ids);

  /// Abre el formulario con todo relleno menos la categoría, que es lo único que la
  /// notificación no puede saber.
  Future<void> _registrar(BuildContext context, WidgetRef ref) async {
    final periodo = ref.read(periodoProvider);
    final pago = pendiente.pago;

    // Una compra se imputa al mes que se está viendo aunque su fecha sea del anterior, que es
    // lo normal a fin de mes. Solo se rechaza lo que queda demasiado atrás: ahí es más probable
    // que sea una captura vieja olvidada en la bandeja que algo que se quiera apuntar aquí.
    final mesAnterior = DateTime(periodo.year, periodo.month - 1);
    final esDelMes =
        pago.instante.year == periodo.year &&
        pago.instante.month == periodo.month;
    final esDelAnterior =
        pago.instante.year == mesAnterior.year &&
        pago.instante.month == mesAnterior.month;

    if (!esDelMes && !esDelAnterior) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ese pago es de ${Formato.mesYAnio(pago.instante).toLowerCase()}. '
            'Cambia a ese mes para apuntarlo.',
          ),
        ),
      );
      return;
    }

    final datos = await showModalBottomSheet<DatosCompra>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioCompra(
        periodo: periodo,
        inicial: DatosCompra(
          descripcion: pendiente.descripcionSugerida,
          monto: pago.monto,
          categoria: CategoriaGasto.antojos,
          fecha: DateTime(
            pago.instante.year,
            pago.instante.month,
            pago.instante.day,
          ),
          medio: pendiente.medioSugerido,
          tarjetaId: pendiente.tarjeta?.id,
        ),
      ),
    );
    if (datos == null) return;

    try {
      await ref
          .read(comprasProvider.notifier)
          .registrar(
            descripcion: datos.descripcion,
            monto: datos.monto,
            categoria: datos.categoria,
            fecha: datos.fecha,
            medio: datos.medio,
            tarjetaId: datos.tarjetaId,
          );
      await _descartar(ref);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

/// Avisa de que la notificación menciona una tarjeta que la aplicación no sabe reconocer.
///
/// Importa más de lo que parece: sin identificar la tarjeta no se sabe si el pago fue con
/// débito o con crédito, y de eso depende de qué mes sale el dinero.
class _AvisoTarjetaSinReconocer extends StatelessWidget {
  const _AvisoTarjetaSinReconocer({required this.pendiente});

  final PagoPendiente pendiente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pista =
        pendiente.pago.apodoTarjeta ??
        'terminada en ${pendiente.pago.ultimos4}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tema.colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 16, color: tema.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No sé qué tarjeta es «$pista». Añádela en Tarjetas para que los '
              'próximos pagos se reconozcan solos.',
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
