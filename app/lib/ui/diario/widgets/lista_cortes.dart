import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../datos/cliente_api.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/compras.dart';
import '../../../estado/mes.dart';

/// Los cortes de tarjeta que vencen en el mes que se está viendo.
///
/// Un corte reúne compras hechas en meses distintos: lo que se paga en octubre son las compras
/// del 16 de agosto en adelante y hasta el 15 de septiembre. Por eso no basta con mirar las
/// compras del mes; hace falta este bloque aparte.
class ListaCortes extends ConsumerWidget {
  const ListaCortes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cortes = ref.watch(cortesDelPeriodoProvider);

    return cortes.maybeWhen(
      data: (lista) {
        if (lista.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final corte in lista) ...[
              _TarjetaCorte(corte: corte),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
          ],
        );
      },
      // Un fallo aquí no debe tapar la lista de compras, que es lo principal de la pantalla.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _TarjetaCorte extends ConsumerWidget {
  const _TarjetaCorte({required this.corte});

  final CorteTarjeta corte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final color = corte.saldado
        ? tema.colorScheme.primary
        : tema.colorScheme.tertiary;

    return Card(
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    corte.tarjetaNombre,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  Formato.dinero(corte.total),
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              corte.saldado
                  ? 'Corte pagado'
                  : corte.vencimiento == null
                  ? 'Vence este mes'
                  : 'Vence el ${Formato.fecha(corte.vencimiento!)}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            if (corte.compras.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${corte.compras.length} '
                '${corte.compras.length == 1 ? 'compra' : 'compras'} '
                'de ${_mesesDeOrigen()}',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cambiarEstado(context, ref),
                icon: Icon(
                  corte.saldado ? Icons.undo : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(
                  corte.saldado ? 'Marcar sin pagar' : 'Marcar pagado',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Los meses en que se hicieron las compras de este corte, sin repetir.
  String _mesesDeOrigen() {
    final meses = <String>{};
    for (final compra in corte.compras) {
      meses.add(Formato.nombreDeMes(compra.fecha.month).toLowerCase());
    }
    return meses.join(' y ');
  }

  Future<void> _cambiarEstado(BuildContext context, WidgetRef ref) async {
    final saldar = ref.read(saldarCorteProvider);
    final periodo = ref.read(periodoProvider);

    try {
      await saldar(corte.tarjetaId, periodo, pagado: !corte.saldado);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}
