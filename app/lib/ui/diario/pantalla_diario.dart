import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/modelos.dart';
import '../../estado/compras.dart';
import '../../estado/mes.dart';
import 'widgets/bandeja_capturas.dart';
import 'widgets/formulario_compra.dart';
import 'widgets/lista_cortes.dart';
import 'widgets/tarjetas_gestion.dart';

/// Los gastos del día a día: lo que se va en agua, gaseosas y antojos.
///
/// Es un apartado aparte del de gastos del mes a propósito. Los gastos fijos son media docena
/// de compromisos grandes que se revisan una vez al mes; esto son muchos importes pequeños que
/// se apuntan sobre la marcha. Mezclarlos hacía ilegibles las dos listas.
class PantallaDiario extends ConsumerWidget {
  const PantallaDiario({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compras = ref.watch(comprasProvider);
    final periodo = ref.watch(periodoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos diarios'),
        actions: [
          IconButton(
            tooltip: 'Tarjetas',
            icon: const Icon(Icons.credit_card_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const GestionTarjetas(),
            ),
          ),
        ],
      ),
      body: compras.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(
          mensaje: error is ErrorApi
              ? error.mensaje
              : 'No se pudieron cargar las compras',
          alReintentar: () => ref.read(comprasProvider.notifier).cargar(),
        ),
        data: (datos) => _Contenido(datos: datos, periodo: periodo),
      ),
      floatingActionButton: compras.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => registrarCompra(context, ref),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Apuntar'),
            )
          : null,
    );
  }

  /// Abre el formulario y registra la compra. Se expone para poder llamarlo desde el mes.
  static Future<void> registrarCompra(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final periodo = ref.read(periodoProvider);
    final sugerencias = ref
        .read(comprasProvider)
        .maybeWhen(
          data: (datos) => _descripcionesFrecuentes(datos.compras),
          orElse: () => const <String>[],
        );

    final nueva = await showModalBottomSheet<DatosCompra>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FormularioCompra(periodo: periodo, sugerencias: sugerencias),
    );
    if (nueva == null) return;

    try {
      await ref
          .read(comprasProvider.notifier)
          .registrar(
            descripcion: nueva.descripcion,
            monto: nueva.monto,
            categoria: nueva.categoria,
            fecha: nueva.fecha,
            medio: nueva.medio,
            tarjetaId: nueva.tarjetaId,
          );
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  /// Lo que más se repite este mes, para poder apuntarlo de un toque.
  static List<String> _descripcionesFrecuentes(List<Compra> compras) {
    final veces = <String, int>{};
    for (final compra in compras) {
      veces.update(compra.descripcion, (n) => n + 1, ifAbsent: () => 1);
    }
    final ordenadas = veces.keys.toList()
      ..sort((a, b) => veces[b]!.compareTo(veces[a]!));
    return ordenadas;
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.datos, required this.periodo});

  final ComprasDelMes datos;
  final DateTime periodo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 720.0
        : double.infinity;

    return RefreshIndicator(
      onRefresh: () => ref.read(comprasProvider.notifier).refrescar(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Resumen(datos: datos, periodo: periodo),
              const SizedBox(height: 16),

              const BandejaCapturas(),
              const ListaCortes(),

              if (datos.compras.isEmpty)
                const _SinCompras()
              else
                ..._porDias(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  /// Las compras agrupadas por día, del más reciente al más antiguo.
  ///
  /// Agrupar por día y no mostrar una lista plana da algo que una lista plana no da: ver de un
  /// vistazo qué días se dispara el gasto.
  List<Widget> _porDias(BuildContext context, WidgetRef ref) {
    final porDia = <DateTime, List<Compra>>{};
    for (final compra in datos.compras) {
      porDia.putIfAbsent(compra.fecha, () => []).add(compra);
    }

    final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      const SizedBox(height: 8),
      for (final dia in dias) ...[
        _EncabezadoDia(
          fecha: dia,
          total: porDia[dia]!.fold<double>(0, (suma, c) => suma + c.monto),
        ),
        const SizedBox(height: 6),
        for (final compra in porDia[dia]!) ...[
          _FilaCompra(compra: compra),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.datos, required this.periodo});

  final ComprasDelMes datos;
  final DateTime periodo;

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
              Formato.mesYAnio(periodo),
              style: tema.textTheme.labelMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formato.dinero(datos.total),
              style: tema.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'en compras del día a día',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            if (datos.aCredito > 0) ...[
              const Divider(height: 24),
              _Linea(
                icono: Icons.payments_outlined,
                etiqueta: 'Ya salió del bolsillo',
                valor: datos.inmediato,
              ),
              const SizedBox(height: 6),
              _Linea(
                icono: Icons.credit_card,
                etiqueta: 'A crédito, se paga después',
                valor: datos.aCredito,
                color: tema.colorScheme.tertiary,
              ),
            ],

            if (datos.porDia.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _Dato(
                      etiqueta: 'Días con gasto',
                      valor: '${datos.porDia.length}',
                    ),
                  ),
                  Expanded(
                    child: _Dato(
                      etiqueta: 'Media por día',
                      valor: Formato.dinero(datos.promedioPorDia),
                    ),
                  ),
                  if (datos.diaMasCaro case final dia?)
                    Expanded(
                      child: _Dato(
                        etiqueta: 'Día más caro',
                        valor: Formato.fechaCorta(dia.fecha),
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

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: tema.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          etiqueta,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.color,
  });

  final IconData icono;
  final String etiqueta;
  final double valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tinte = color ?? tema.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icono, size: 18, color: tinte),
        const SizedBox(width: 10),
        Expanded(child: Text(etiqueta, style: tema.textTheme.bodyMedium)),
        Text(
          Formato.dinero(valor),
          style: tema.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EncabezadoDia extends StatelessWidget {
  const _EncabezadoDia({required this.fecha, required this.total});

  final DateTime fecha;
  final double total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Text(
            '${Formato.diaDeLaSemana(fecha)} ${fecha.day}',
            style: tema.textTheme.labelLarge?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: tema.colorScheme.outlineVariant, height: 1),
          ),
          const SizedBox(width: 8),
          Text(
            Formato.dinero(total),
            style: tema.textTheme.labelLarge?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaCompra extends ConsumerWidget {
  const _FilaCompra({required this.compra});

  final Compra compra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Dismissible(
      key: ValueKey(compra.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: tema.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: tema.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => _confirmarBorrado(context),
      onDismissed: (_) => _eliminar(context, ref),
      child: Material(
        color: tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editar(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _IconoMedio(compra: compra),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compra.descripcion,
                        style: tema.textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitulo(),
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formato.dinero(compra.monto),
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Categoría y, si fue a crédito, cuándo se paga: es lo que no se ve al pagar con el móvil.
  String _subtitulo() {
    if (compra.medio != MedioPago.credito) return compra.categoria.etiqueta;

    final tarjeta = compra.tarjetaNombre ?? 'Crédito';
    return '${compra.categoria.etiqueta} · $tarjeta, '
        'se paga el ${Formato.fechaCorta(compra.vencimiento)}';
  }

  Future<bool> _confirmarBorrado(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Borrar la compra?'),
        content: Text(
          '${compra.descripcion} · ${Formato.dinero(compra.monto)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(comprasProvider.notifier).eliminar(compra.id);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final cambios = await showModalBottomSheet<DatosCompra>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FormularioCompra(
        periodo: DateTime(compra.fecha.year, compra.fecha.month),
        compra: compra,
      ),
    );
    if (cambios == null) return;

    try {
      await ref
          .read(comprasProvider.notifier)
          .actualizar(
            compra.id,
            descripcion: cambios.descripcion,
            monto: cambios.monto,
            categoria: cambios.categoria,
            fecha: cambios.fecha,
            medio: cambios.medio,
            tarjetaId: cambios.tarjetaId,
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

class _IconoMedio extends StatelessWidget {
  const _IconoMedio({required this.compra});

  final Compra compra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final (icono, color) = switch (compra.medio) {
      MedioPago.efectivo => (Icons.payments_outlined, tema.colorScheme.primary),
      MedioPago.debito => (
        Icons.account_balance_outlined,
        tema.colorScheme.secondary,
      ),
      MedioPago.credito => (Icons.credit_card, tema.colorScheme.tertiary),
    };

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icono, size: 19, color: color),
    );
  }
}

class _SinCompras extends StatelessWidget {
  const _SinCompras();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 44,
            color: tema.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('Nada apuntado este mes', style: tema.textTheme.titleMedium),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Aquí van las compras sueltas del día a día: el agua, la gaseosa, '
              'el pasaje que no estaba previsto.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
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
            Icon(
              Icons.cloud_off,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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
