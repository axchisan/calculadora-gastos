import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dinero.dart';
import '../../../core/formato.dart';
import '../../../dominio/credito.dart';
import '../../../estado/creditos.dart';

/// Qué pasaría si se abonara de más a capital.
///
/// Es la razón de que este módulo exista. Al 76% efectivo anual, adelantar no ahorra «una
/// cuota»: ahorra todos los intereses que ese capital habría generado hasta el final del plan.
/// Sin verlo en una cifra, la decisión de si conviene se toma a ciegas.
class SimuladorAbono extends ConsumerStatefulWidget {
  const SimuladorAbono({required this.credito, super.key});

  final Credito credito;

  @override
  ConsumerState<SimuladorAbono> createState() => _SimuladorAbonoState();
}

class _SimuladorAbonoState extends ConsumerState<SimuladorAbono> {
  final _abono = TextEditingController();

  ModoDeAbono _modo = ModoDeAbono.reducirPlazo;
  double? _abonoConfirmado;

  @override
  void dispose() {
    _abono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

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
            Text('¿Y si abono de más?', style: tema.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Todo lo que abones de más va contra el capital, y ese capital deja de '
              'generar intereses hasta el final del plan.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _abono,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [FormatoDeImporte()],
              style: tema.textTheme.headlineSmall,
              decoration: InputDecoration(
                prefixText: r'$ ',
                labelText: 'Cuánto abonas',
                helperText:
                    'Como mucho ${Formato.dinero(widget.credito.saldo)}, '
                    'que es lo que debes',
              ),
              onChanged: (_) => setState(() => _abonoConfirmado = null),
            ),
            const SizedBox(height: 16),

            SegmentedButton<ModoDeAbono>(
              segments: const [
                ButtonSegment(
                  value: ModoDeAbono.reducirPlazo,
                  icon: Icon(Icons.fast_forward),
                  label: Text('Terminar antes'),
                ),
                ButtonSegment(
                  value: ModoDeAbono.reducirCuota,
                  icon: Icon(Icons.trending_down),
                  label: Text('Bajar la cuota'),
                ),
              ],
              selected: {_modo},
              onSelectionChanged: (s) => setState(() => _modo = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _modo == ModoDeAbono.reducirPlazo
                  ? 'Sigues pagando lo mismo cada mes y el crédito se acaba antes. Suele '
                        'ahorrar bastante más.'
                  : 'Mantienes las mismas cuotas y cada una baja de importe.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _calcular,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Calcular'),
            ),

            if (_abonoConfirmado case final abono?) ...[
              const SizedBox(height: 20),
              _Resultado(
                peticion: PeticionDeSimulacion(
                  creditoId: widget.credito.id,
                  abono: abono,
                  modo: _modo,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _calcular() {
    final abono = Dinero.interpretar(_abono.text);
    if (abono == null || abono <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe cuánto quieres abonar')),
      );
      return;
    }
    setState(() => _abonoConfirmado = abono);
  }
}

class _Resultado extends ConsumerWidget {
  const _Resultado({required this.peticion});

  final PeticionDeSimulacion peticion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return ref
        .watch(simulacionProvider(peticion))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              error.toString(),
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          ),
          data: (s) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tema.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Te ahorras ${Formato.dinero(s.ahorroInteres)} de intereses',
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tema.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r'Por cada $100 que adelantas dejas de pagar '
                  '${Formato.porcentaje(s.rendimiento)} en intereses.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),

                const Divider(height: 24),

                if (s.cuotasAhorradas > 0)
                  _Cambio(
                    etiqueta: 'Cuotas',
                    antes: '${s.cuotasAntes}',
                    despues: '${s.cuotasDespues}',
                    nota: s.cuotasAhorradas == 1
                        ? 'una cuota menos'
                        : '${s.cuotasAhorradas} cuotas menos',
                  )
                else
                  _Cambio(
                    etiqueta: 'Cuota mensual',
                    antes: Formato.dinero(s.cuotaAntes),
                    despues: Formato.dinero(s.cuotaDespues),
                    nota: 'baja ${Formato.dinero(s.bajaLaCuota)} al mes',
                  ),

                const SizedBox(height: 8),
                _Cambio(
                  etiqueta: 'Intereses por pagar',
                  antes: Formato.dinero(s.interesAntes),
                  despues: Formato.dinero(s.interesDespues),
                ),
                const SizedBox(height: 8),
                _Cambio(
                  etiqueta: 'Total por pagar',
                  antes: Formato.dinero(s.totalAntes),
                  despues: Formato.dinero(s.totalDespues),
                ),

                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 16,
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        // La cifra honesta: lo que se ahorra descontando el propio abono, que
                        // también sale del bolsillo.
                        'Contando el abono, sales ganando '
                        '${Formato.dinero(s.ahorroNeto)}.',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}

class _Cambio extends StatelessWidget {
  const _Cambio({
    required this.etiqueta,
    required this.antes,
    required this.despues,
    this.nota,
  });

  final String etiqueta;
  final String antes;
  final String despues;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(etiqueta, style: tema.textTheme.bodyMedium)),
            Text(
              antes,
              style: tema.textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 14),
            const SizedBox(width: 8),
            Text(
              despues,
              style: tema.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (nota case final aclaracion?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              aclaracion,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
