import 'package:flutter/material.dart';

import '../../../core/tema.dart';
import '../../../dominio/modelos.dart';

/// Rejilla mensual con un día por celda.
///
/// El color indica de un vistazo qué clase de día es, y el número de la esquina cuántos
/// pasajes cuesta. Es la pantalla donde se hace el trabajo de verdad: ajustar el mes es tocar
/// los días que no encajan con la propuesta.
class CalendarioMes extends StatelessWidget {
  const CalendarioMes({
    required this.semanas,
    required this.alTocarDia,
    super.key,
  });

  final List<List<DiaTransporte?>> semanas;
  final void Function(DiaTransporte dia) alTocarDia;

  static const List<String> _cabecera = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            for (final letra in _cabecera)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      letra,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: esquema.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final semana in semanas)
          Row(
            children: [
              for (final dia in semana)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: dia == null
                        ? const AspectRatio(aspectRatio: 1, child: SizedBox())
                        : _Celda(dia: dia, alTocar: () => alTocarDia(dia)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.dia, required this.alTocar});

  final DiaTransporte dia;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = colorDeTipo(dia.tipo, esquema);
    final sinCosto = dia.pasajes == 0;

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: color.withValues(alpha: sinCosto ? 0.08 : 0.18),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: dia.confirmado
                  // El día ya transcurrió y se confirmó lo gastado.
                  ? Border.all(color: color, width: 1.6)
                  : null,
            ),
            padding: const EdgeInsets.all(3),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    '${dia.fecha.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sinCosto ? esquema.onSurfaceVariant : color,
                    ),
                  ),
                ),

                if (dia.hayKarate)
                  const Align(
                    alignment: Alignment.topRight,
                    child: Icon(Icons.sports_martial_arts, size: 11),
                  ),

                if (dia.pasajes > 0)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${dia.pasajes}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                if (dia.overrideManual)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Icon(
                      Icons.edit,
                      size: 9,
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Color asociado a cada clase de día.
Color colorDeTipo(TipoDia tipo, ColorScheme esquema) => switch (tipo) {
  TipoDia.oficina => esquema.primary,
  TipoDia.remoto => Tema.neutro,
  TipoDia.festivo => Tema.pendiente,
  TipoDia.finDeSemana => esquema.outline,
  TipoDia.vacaciones => Tema.positivo,
  TipoDia.ausente => esquema.outline,
};

/// Leyenda de los colores del calendario.
class LeyendaCalendario extends StatelessWidget {
  const LeyendaCalendario({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final tipo in [
          TipoDia.oficina,
          TipoDia.remoto,
          TipoDia.festivo,
          TipoDia.vacaciones,
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorDeTipo(tipo, esquema).withValues(alpha: 0.35),
                  border: Border.all(color: colorDeTipo(tipo, esquema)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(tipo.etiqueta, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_martial_arts, size: 12),
            const SizedBox(width: 4),
            Text('Karate', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
