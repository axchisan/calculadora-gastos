import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../datos/cliente_api.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/transporte.dart';
import 'calendario_mes.dart';

/// Hoja que se abre al tocar un día del calendario.
///
/// Permite reclasificarlo, fijar los pasajes a mano cuando el cálculo no encaja con la
/// realidad, y confirmarlo una vez transcurrido.
class DetalleDia extends ConsumerWidget {
  const DetalleDia({required this.dia, super.key});

  final DiaTransporte dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final controlador = ref.read(transporteProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Formato.diaDeLaSemana(dia.fecha)} ${dia.fecha.day}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (dia.nombreFestivo != null)
                      Text(
                        dia.nombreFestivo!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorDeTipo(TipoDia.festivo, esquema),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${dia.pasajes} ${dia.pasajes == 1 ? "pasaje" : "pasajes"}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorDeTipo(dia.tipo, esquema),
                      ),
                    ),
                    if (dia.overrideManual)
                      Text(
                        'fijado a mano',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            if (dia.hayKarate) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.sports_martial_arts, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'Hay karate este día',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            Text(
              'Qué pasa este día',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),

            // Festivo y fin de semana los determina el calendario, no el usuario.
            Wrap(
              spacing: 8,
              children: [
                for (final tipo in TipoDia.asignables)
                  ChoiceChip(
                    label: Text(tipo.etiqueta),
                    selected: dia.tipo == tipo,
                    onSelected: (_) async {
                      Navigator.pop(context);
                      await _ejecutar(
                        context,
                        () => controlador.cambiarTipoDia(dia.id, tipo),
                      );
                    },
                  ),
              ],
            ),

            if (dia.tipo == TipoDia.festivo ||
                dia.tipo == TipoDia.finDeSemana) ...[
              const SizedBox(height: 8),
              Text(
                dia.tipo == TipoDia.festivo
                    ? 'Es festivo en Colombia. Si aun así trabajas, márcalo como oficina.'
                    : 'Es fin de semana. Si trabajas, márcalo como oficina.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ],

            const Divider(height: 28),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Fijar los pasajes a mano'),
              subtitle: const Text('Para un día que no encaja con el cálculo'),
              onTap: () async {
                Navigator.pop(context);
                await _pedirPasajes(context, controlador);
              },
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.check_circle_outline),
              title: const Text('Día confirmado'),
              subtitle: const Text('Ya pasó y el gasto fue este'),
              value: dia.confirmado,
              onChanged: (valor) async {
                Navigator.pop(context);
                await _ejecutar(
                  context,
                  () => controlador.confirmarDia(dia.id, valor),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pedirPasajes(
    BuildContext context,
    ControladorTransporte controlador,
  ) async {
    final campo = TextEditingController(text: '${dia.pasajes}');

    final valor = await showDialog<int>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Pasajes del ${dia.fecha.day}'),
        content: TextField(
          controller: campo,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: const InputDecoration(
            helperText: 'El valor se conserva aunque se recalcule el mes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, int.tryParse(campo.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (valor != null && valor >= 0 && context.mounted) {
      await _ejecutar(context, () => controlador.fijarPasajes(dia.id, valor));
    }
  }

  Future<void> _ejecutar(
    BuildContext context,
    Future<void> Function() accion,
  ) async {
    try {
      await accion();
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}
