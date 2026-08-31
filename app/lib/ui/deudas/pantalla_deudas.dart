import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/credito.dart';
import '../../dominio/modelos.dart';
import '../../estado/creditos.dart';
import '../../estado/deudas.dart';
import '../../estado/mes.dart';
import '../creditos/pantalla_credito.dart';
import 'widgets/detalle_deuda.dart';
import 'widgets/formulario_deuda.dart';

/// Deudas externas: tarjetas, préstamos y dinero prestado por familiares o amigos.
class PantallaDeudas extends ConsumerWidget {
  const PantallaDeudas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(deudasProvider);
    final verTodas = ref.watch(verTodasLasDeudasProvider);
    final periodo = ref.watch(periodoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(verTodas ? 'Deudas' : Formato.mesYAnio(periodo)),
        actions: [
          IconButton(
            tooltip: verTodas ? 'Ver solo las del mes' : 'Ver todas',
            icon: Icon(verTodas ? Icons.filter_alt_off : Icons.history),
            onPressed: () => ref
                .read(verTodasLasDeudasProvider.notifier)
                .update((valor) => !valor),
          ),
        ],
      ),
      body: datos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(
          mensaje: error is ErrorApi
              ? error.mensaje
              : 'No se pudieron cargar las deudas',
          alReintentar: () => ref.read(deudasProvider.notifier).cargar(),
        ),
        data: (d) => _Contenido(datos: d),
      ),
      floatingActionButton: datos.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _nuevaDeuda(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Deuda'),
            )
          : null,
    );
  }

  Future<void> _nuevaDeuda(BuildContext context, WidgetRef ref) async {
    final nueva = await showModalBottomSheet<DatosNuevaDeuda>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FormularioDeuda(),
    );
    if (nueva == null) return;

    try {
      await ref
          .read(deudasProvider.notifier)
          .crear(
            acreedor: nueva.acreedor,
            tipo: nueva.tipo,
            montoOriginal: nueva.monto,
            tasaInteresMensual: nueva.tasaInteres,
            cuotaSugerida: nueva.cuota,
          );
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.datos});

  final DatosDeudas datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (datos.deudas.isEmpty) return const _SinDeudas();

    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 720.0
        : double.infinity;

    return RefreshIndicator(
      onRefresh: () => ref.read(deudasProvider.notifier).refrescar(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Resumen(datos: datos),
              const SizedBox(height: 20),

              // Los créditos van arriba: son deudas también, pero con un plan cerrado detrás y
              // mucho más dinero en juego que un préstamo entre amigos.
              const _Creditos(),

              if (datos.activas.isNotEmpty) ...[
                _Encabezado(
                  titulo: 'Pendientes',
                  cantidad: datos.activas.length,
                ),
                const SizedBox(height: 8),
                for (final deuda in datos.activas) ...[
                  _TarjetaDeuda(deuda: deuda),
                  const SizedBox(height: 10),
                ],
              ],

              if (datos.saldadas.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Encabezado(
                  titulo: 'Saldadas',
                  cantidad: datos.saldadas.length,
                ),
                const SizedBox(height: 8),
                for (final deuda in datos.saldadas) ...[
                  _TarjetaDeuda(deuda: deuda),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Los créditos con cuadro de amortización, que son deudas de otra naturaleza.
class _Creditos extends ConsumerWidget {
  const _Creditos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(creditosProvider)
        .maybeWhen(
          data: (creditos) {
            if (creditos.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Encabezado(titulo: 'Créditos', cantidad: creditos.length),
                const SizedBox(height: 8),
                for (final credito in creditos) ...[
                  _TarjetaCredito(credito: credito),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
              ],
            );
          },
          // Un fallo aquí no debe tapar las deudas, que es lo principal de la pantalla.
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _TarjetaCredito extends StatelessWidget {
  const _TarjetaCredito({required this.credito});

  final Credito credito;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PantallaCredito(credito: credito),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 20,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      credito.entidad,
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Formato.dinero(credito.saldo),
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Tema.negativo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(
                        color: tema.colorScheme.surfaceContainerHighest,
                      ),
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
                [
                  '${credito.cuotasPagadas} de ${credito.cuotasTotales} cuotas',
                  if (credito.proximaCuota case final proxima?)
                    'próxima el ${Formato.fechaCorta(proxima.fecha)} '
                        'por ${Formato.dinero(proxima.valorCuota)}',
                ].join(' · '),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              if (credito.tieneVencidas) ...[
                const SizedBox(height: 6),
                Text(
                  credito.cuotasVencidas == 1
                      ? 'Una cuota vencida'
                      : '${credito.cuotasVencidas} cuotas vencidas',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: Tema.negativo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.datos});

  final DatosDeudas datos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debes en total',
              style: textos.labelLarge?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formato.dinero(datos.saldoTotal),
              style: textos.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: datos.saldoTotal > 0 ? Tema.negativo : Tema.positivo,
              ),
            ),

            if (datos.montoOriginalTotal > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Container(color: esquema.surfaceContainerHighest),
                      FractionallySizedBox(
                        widthFactor: datos.proporcionPagada,
                        child: Container(color: Tema.positivo),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Has pagado ${Formato.dinero(datos.montoOriginalTotal - datos.saldoTotal)} '
                'de ${Formato.dinero(datos.montoOriginalTotal)}',
                style: textos.bodySmall,
              ),
            ],

            if (datos.interesMensualTotal > 0) ...[
              const Divider(height: 28),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 18,
                    color: Tema.pendiente,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los intereses suman ${Formato.dinero(datos.interesMensualTotal)} '
                      'cada mes',
                      style: textos.bodySmall,
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

class _TarjetaDeuda extends ConsumerWidget {
  const _TarjetaDeuda({required this.deuda});

  final Deuda deuda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final proporcion = (deuda.porcentajePagado / 100).clamp(0.0, 1.0);

    return Card(
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => DetalleDeuda(deuda: deuda),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icono(deuda.tipo), size: 20, color: esquema.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deuda.acreedor,
                          style: textos.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: deuda.activa
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        Text(
                          deuda.tipo.etiqueta,
                          style: textos.bodySmall?.copyWith(
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formato.dinero(deuda.saldo),
                        style: textos.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: deuda.activa ? Tema.negativo : Tema.positivo,
                        ),
                      ),
                      Text(
                        deuda.activa
                            ? 'de ${Formato.dinero(deuda.montoOriginal)}'
                            : 'saldada',
                        style: textos.labelSmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: proporcion,
                  minHeight: 6,
                  backgroundColor: esquema.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(Tema.positivo),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${deuda.porcentajePagado.toStringAsFixed(0)}% pagado',
                    style: textos.labelSmall,
                  ),
                  const Spacer(),
                  if (deuda.interesMensualEstimado != null &&
                      deuda.interesMensualEstimado! > 0)
                    Text(
                      '+${Formato.dinero(deuda.interesMensualEstimado!)}/mes de interés',
                      style: textos.labelSmall?.copyWith(color: Tema.pendiente),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icono(TipoDeuda tipo) => switch (tipo) {
    TipoDeuda.tarjetaCredito => Icons.credit_card,
    TipoDeuda.prestamoBancario => Icons.account_balance,
    TipoDeuda.familiar => Icons.family_restroom,
    TipoDeuda.amigo => Icons.people_outline,
    TipoDeuda.otro => Icons.receipt_long_outlined,
  };
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo, required this.cantidad});

  final String titulo;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            '($cantidad)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SinDeudas extends ConsumerWidget {
  const _SinDeudas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Con el filtro por mes activo, «no debes nada» sería engañoso: puede haber deudas en
    // otros meses. Lo que no hay es nada que pague este.
    final porMes = !ref.watch(verTodasLasDeudasProvider);
    final periodo = ref.watch(periodoProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Tema.positivo,
            ),
            const SizedBox(height: 16),
            Text(
              porMes
                  ? 'Nada que pagar en ${Formato.mesYAnio(periodo).toLowerCase()}'
                  : 'No debes nada',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              porMes
                  ? 'Aquí salen las deudas que seguías debiendo este mes y las que saldaste '
                        'en él. Toca el icono del historial para verlas todas.'
                  : 'Si le debes a alguien —la tarjeta, un familiar, un amigo— añádelo aquí '
                        'para que cuente en tu presupuesto.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Tema.pendiente,
            ),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
