import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/credito.dart';
import '../../estado/creditos.dart';
import 'widgets/simulador_abono.dart';

/// El detalle de un crédito: por dónde va, qué queda y qué pasaría si se adelanta dinero.
class PantallaCredito extends ConsumerWidget {
  const PantallaCredito({required this.credito, super.key});

  final Credito credito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se relee de la lista viva para que la pantalla se actualice al marcar una cuota.
    final actual = ref
        .watch(creditosProvider)
        .maybeWhen(
          data: (lista) => lista.firstWhere(
            (c) => c.id == credito.id,
            orElse: () => credito,
          ),
          orElse: () => credito,
        );

    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 720.0
        : double.infinity;

    return Scaffold(
      appBar: AppBar(title: Text(actual.entidad)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Cabecera(credito: actual),
              const SizedBox(height: 16),
              _LoQueCuesta(credito: actual),
              const SizedBox(height: 16),
              _Cuadro(creditoId: actual.id),
            ],
          ),
        ),
      ),
      floatingActionButton: actual.estaSaldado
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SimuladorAbono(credito: actual),
              ),
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('¿Y si abono de más?'),
            ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.credito});

  final Credito credito;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debes ahora',
              style: tema.textTheme.labelMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              Formato.dinero(credito.saldo),
              style: tema.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: credito.estaSaldado ? Tema.positivo : Tema.negativo,
              ),
            ),
            if (credito.descripcion case final que?)
              Text(
                que,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),

            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: tema.colorScheme.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: (credito.porcentajePagado / 100).clamp(
                        0.0,
                        1.0,
                      ),
                      child: Container(color: Tema.positivo),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${credito.cuotasPagadas} de ${credito.cuotasTotales} cuotas · '
              '${Formato.porcentaje(credito.porcentajePagado)} pagado',
              style: tema.textTheme.bodySmall,
            ),

            if (credito.tieneVencidas) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Tema.negativo,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    credito.cuotasVencidas == 1
                        ? 'Tienes una cuota vencida'
                        : 'Tienes ${credito.cuotasVencidas} cuotas vencidas',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: Tema.negativo,
                    ),
                  ),
                ],
              ),
            ],

            if (credito.proximaCuota case final proxima?) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Próxima cuota el ${Formato.fecha(proxima.fecha)}',
                      style: tema.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    Formato.dinero(proxima.valorCuota),
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lo que el crédito cuesta por encima de lo prestado.
///
/// No aparece en ningún extracto y es la cifra que cambia la percepción del préstamo: al 76%
/// efectivo anual se devuelve más de una vez y media lo recibido.
class _LoQueCuesta extends StatelessWidget {
  const _LoQueCuesta({required this.credito});

  final Credito credito;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lo que cuesta', style: tema.textTheme.titleSmall),
            const SizedBox(height: 12),

            _Fila('Te prestaron', Formato.dinero(credito.montoOriginal)),
            _Fila(
              'Intereses y cargos',
              Formato.dinero(credito.costeTotal),
              resaltado: true,
            ),
            const Divider(height: 20),
            _Fila(
              'Devuelves en total',
              Formato.dinero(credito.montoOriginal + credito.costeTotal),
              resaltado: true,
            ),

            const SizedBox(height: 10),
            Text(
              'Devuelves ${credito.vecesLoPrestado.toStringAsFixed(2)} veces lo que te '
              'prestaron'
              '${credito.tasaEa == null ? '' : ', al ${Formato.porcentaje(credito.tasaEa!)} efectivo anual'}.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            const Divider(height: 24),
            _Fila('Ya pagado', Formato.dinero(credito.totalPagado)),
            _Fila('Falta por pagar', Formato.dinero(credito.totalPendiente)),
            _Fila(
              'De eso, intereses',
              Formato.dinero(credito.interesPendiente),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor, {this.resaltado = false});

  final String etiqueta;
  final String valor;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: tema.textTheme.bodyMedium)),
          Text(
            valor,
            style: tema.textTheme.bodyMedium?.copyWith(
              fontWeight: resaltado ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// El cuadro de amortización, cuota a cuota.
class _Cuadro extends ConsumerWidget {
  const _Cuadro({required this.creditoId});

  final String creditoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return ref
        .watch(cuadroProvider(creditoId))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No se pudo cargar el cuadro'),
          ),
          data: (cuotas) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Cuadro de pagos',
                  style: tema.textTheme.titleSmall,
                ),
              ),
              for (final cuota in cuotas) ...[
                _FilaCuota(cuota: cuota),
                const SizedBox(height: 6),
              ],
            ],
          ),
        );
  }
}

class _FilaCuota extends ConsumerWidget {
  const _FilaCuota({required this.cuota});

  final CuotaCredito cuota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final vencida = cuota.estaVencida(DateTime.now());

    return Material(
      color: cuota.pagada
          ? Tema.positivo.withValues(alpha: 0.08)
          : vencida
          ? Tema.negativo.withValues(alpha: 0.08)
          : tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _cambiar(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    cuota.pagada
                        ? Icons.check_circle
                        : vencida
                        ? Icons.error_outline
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: cuota.pagada
                        ? Tema.positivo
                        : vencida
                        ? Tema.negativo
                        : tema.colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuota ${cuota.numero}',
                          style: tema.textTheme.bodyLarge,
                        ),
                        Text(
                          Formato.fecha(cuota.fecha),
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formato.dinero(cuota.valorCuota),
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              if (cuota.valorCuota > 0) ...[
                const SizedBox(height: 8),
                // La barra enseña qué parte de la cuota mata deuda de verdad. Al principio del
                // plan es una minoría, y es lo que explica que el saldo baje tan despacio.
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 5,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (cuota.proporcionCapital * 1000).round(),
                          child: Container(color: Tema.positivo),
                        ),
                        Expanded(
                          flex: ((1 - cuota.proporcionCapital) * 1000).round(),
                          child: Container(color: Tema.pendiente),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capital ${Formato.dinero(cuota.capital)} · '
                  'interés ${Formato.dinero(cuota.interes)}'
                  '${cuota.cargos > 0 ? ' · cargos ${Formato.dinero(cuota.cargos)}' : ''}',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cambiar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(marcarCuotaProvider)(cuota.id, pagada: !cuota.pagada);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}
