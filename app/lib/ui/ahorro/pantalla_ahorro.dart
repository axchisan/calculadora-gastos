import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dinero.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../datos/repositorio_ahorro.dart';
import '../../dominio/modelos.dart';
import '../../estado/ahorro.dart';
import 'widgets/formulario_meta.dart';

/// Metas de ahorro y reparto del dinero disponible.
class PantallaAhorro extends ConsumerWidget {
  const PantallaAhorro({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(ahorroProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ahorro')),
      body: datos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(
          mensaje: error is ErrorApi
              ? error.mensaje
              : 'No se pudo cargar el ahorro',
          alReintentar: () => ref.read(ahorroProvider.notifier).cargar(),
        ),
        data: (d) => _Contenido(datos: d),
      ),
      floatingActionButton: datos.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _nuevaMeta(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Meta'),
            )
          : null,
    );
  }

  Future<void> _nuevaMeta(BuildContext context, WidgetRef ref) async {
    final nueva = await showModalBottomSheet<DatosNuevaMeta>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FormularioMeta(),
    );
    if (nueva == null) return;

    try {
      await ref
          .read(ahorroProvider.notifier)
          .crear(
            nombre: nueva.nombre,
            tipoAsignacion: nueva.tipo,
            valor: nueva.valor,
            metaMonto: nueva.objetivo,
            prioridad: nueva.prioridad,
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

  final DatosAhorro datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (datos.metas.isEmpty) return const _SinMetas();

    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 720.0
        : double.infinity;

    return RefreshIndicator(
      onRefresh: () => ref.read(ahorroProvider.notifier).refrescar(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Resumen(datos: datos),
              if (datos.distribucion.isNotEmpty) ...[
                const SizedBox(height: 20),
                _Distribucion(datos: datos),
              ],
              const SizedBox(height: 20),
              for (final meta in datos.metas) ...[
                _TarjetaMeta(meta: meta),
                const SizedBox(height: 10),
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

  final DatosAhorro datos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tienes ahorrado',
              style: textos.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formato.dinero(datos.saldoTotal),
              style: textos.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Tema.positivo,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${datos.activas.length} '
              '${datos.activas.length == 1 ? "meta activa" : "metas activas"}',
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reparto que propone el sistema con el dinero que queda del mes.
class _Distribucion extends ConsumerWidget {
  const _Distribucion({required this.datos});

  final DatosAhorro datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: esquema.primary),
                const SizedBox(width: 8),
                Text(
                  'Reparto sugerido',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  Formato.dinero(datos.totalSugerido),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),

            for (final asignacion in datos.distribucion)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(asignacion.nombre)),
                    Text(
                      Formato.dinero(asignacion.monto),
                      style: TextStyle(
                        color: asignacion.monto > 0
                            ? Tema.positivo
                            : esquema.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            Text(
              'Es solo una propuesta con lo que queda del mes: no mueve dinero hasta que la '
              'apliques.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (datos.totalSugerido > 0)
              FilledButton.tonal(
                onPressed: () => _aplicar(context, ref),
                child: const Text('Aplicar el reparto'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _aplicar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Aplicar el reparto'),
        content: Text(
          'Se registrará un aporte en cada meta por un total de '
          '${Formato.dinero(datos.totalSugerido)}. Los aportes se descuentan del disponible '
          'de este mes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (!(confirmado ?? false)) return;

    try {
      await ref.read(ahorroProvider.notifier).aplicarDistribucion();
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

class _TarjetaMeta extends ConsumerWidget {
  const _TarjetaMeta({required this.meta});

  final MetaAhorro meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final progreso = meta.porcentajeAlcanzado;

    return Card(
      child: InkWell(
        onTap: () => _movimiento(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.nombre,
                          style: textos.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _reglaLegible(meta),
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
                        Formato.dinero(meta.saldoAcumulado),
                        style: textos.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Tema.positivo,
                        ),
                      ),
                      if (meta.metaMonto != null)
                        Text(
                          'de ${Formato.dinero(meta.metaMonto!)}',
                          style: textos.labelSmall?.copyWith(
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              if (progreso != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (progreso / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: esquema.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(Tema.positivo),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${progreso.toStringAsFixed(0)}% del objetivo',
                  style: textos.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _reglaLegible(MetaAhorro meta) => switch (meta.tipoAsignacion) {
    TipoAsignacion.montoFijo => '${Formato.dinero(meta.valor)} cada mes',
    TipoAsignacion.porcentajeIngreso =>
      '${meta.valor.toStringAsFixed(0)}% del ingreso',
    TipoAsignacion.porcentajeSobrante =>
      '${meta.valor.toStringAsFixed(0)}% de lo que sobre',
  };

  Future<void> _movimiento(BuildContext context, WidgetRef ref) async {
    final accion = await showModalBottomSheet<TipoMovimiento>(
      context: context,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                meta.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(Formato.dinero(meta.saldoAcumulado)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add, color: Tema.positivo),
              title: const Text('Aportar'),
              onTap: () => Navigator.pop(contexto, TipoMovimiento.aporte),
            ),
            ListTile(
              leading: const Icon(Icons.remove, color: Tema.negativo),
              title: const Text('Retirar'),
              onTap: () => Navigator.pop(contexto, TipoMovimiento.retiro),
            ),
          ],
        ),
      ),
    );

    if (accion == null || !context.mounted) return;

    final campo = TextEditingController();
    final monto = await showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(accion == TipoMovimiento.aporte ? 'Aportar' : 'Retirar'),
        content: TextField(
          controller: campo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [FormatoDeImporte()],
          decoration: InputDecoration(
            prefixText: r'$ ',
            helperText: accion == TipoMovimiento.retiro
                ? 'Disponible ${Formato.dinero(meta.saldoAcumulado)}'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(contexto, Dinero.interpretar(campo.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (monto == null || monto <= 0 || !context.mounted) return;

    try {
      await ref
          .read(ahorroProvider.notifier)
          .registrarMovimiento(meta.id, tipo: accion, monto: monto);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

class _SinMetas extends StatelessWidget {
  const _SinMetas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin metas de ahorro',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Crea una meta para repartir lo que te sobra: un fondo de emergencia, un viaje, '
              'lo que sea. El sistema te propondrá cuánto destinar cada mes.',
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
