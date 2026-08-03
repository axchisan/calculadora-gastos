import 'package:flutter/material.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../estado/transporte.dart';

/// Cabecera con el costo del mes y el desglose de días.
///
/// Cuando ya hay días confirmados, muestra además cuánto se lleva gastado frente a lo
/// presupuestado: es la forma de notar a media cuenta que el mes se está desviando.
class ResumenTransporteTarjeta extends StatelessWidget {
  const ResumenTransporteTarjeta({required this.datos, super.key});

  final DatosTransporte datos;

  @override
  Widget build(BuildContext context) {
    final r = datos.resumen;
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final hayConfirmados = r.pasajesGastados > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Costo del mes',
              style: textos.labelLarge?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Formato.dinero(r.costoTotal),
                  style: textos.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: esquema.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${r.totalPasajes} pasajes',
                  style: textos.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            if (hayConfirmados) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Container(color: esquema.surfaceContainerHighest),
                      FractionallySizedBox(
                        widthFactor: datos.proporcionConfirmada,
                        child: Container(color: esquema.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Gastado ${Formato.dinero(r.costoConfirmado)}',
                    style: textos.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    'Falta ${Formato.dinero(r.costoPendiente)}',
                    style: textos.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 28),

            Row(
              children: [
                _Dato(
                  valor: '${r.diasOficina}',
                  etiqueta: 'Oficina',
                  color: esquema.primary,
                ),
                _Dato(
                  valor: '${r.diasRemotos}',
                  etiqueta: 'En casa',
                  color: Tema.neutro,
                ),
                _Dato(
                  valor: '${r.diasFestivos}',
                  etiqueta: 'Festivos',
                  color: Tema.pendiente,
                ),
                _Dato(
                  valor: '${r.diasKarate}',
                  etiqueta: 'Karate',
                  color: esquema.tertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
