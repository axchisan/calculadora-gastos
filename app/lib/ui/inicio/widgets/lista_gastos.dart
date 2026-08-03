import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../datos/cliente_api.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/mes.dart';

/// Gastos del mes, separados entre lo que falta por pagar y lo ya saldado.
class ListaGastos extends ConsumerWidget {
  const ListaGastos({required this.datos, super.key});

  final DatosMes datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientes = datos.pendientes;
    final pagados = datos.pagados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendientes.isNotEmpty) ...[
          _Encabezado(
            titulo: 'Por pagar',
            cantidad: pendientes.length,
            monto: datos.resumen.gastoPendiente,
            color: Tema.pendiente,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < pendientes.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _FilaGasto(
                    gasto: pendientes[i],
                    cerrado: datos.resumen.cerrado,
                  ),
                ],
              ],
            ),
          ),
        ],

        if (pagados.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Encabezado(
            titulo: 'Pagado',
            cantidad: pagados.length,
            monto: datos.resumen.gastoPagado,
            color: Tema.positivo,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < pagados.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _FilaGasto(gasto: pagados[i], cerrado: datos.resumen.cerrado),
                ],
              ],
            ),
          ),
        ],

        if (pendientes.isEmpty && pagados.isEmpty) const _SinGastos(),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.titulo,
    required this.cantidad,
    required this.monto,
    required this.color,
  });

  final String titulo;
  final int cantidad;
  final double monto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            titulo,
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            '($cantidad)',
            style: textos.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            Formato.dinero(monto),
            style: textos.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaGasto extends ConsumerWidget {
  const _FilaGasto({required this.gasto, required this.cerrado});

  final Gasto gasto;
  final bool cerrado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagado = gasto.estado == EstadoGasto.pagado;
    final parcial = gasto.estado == EstadoGasto.parcial;
    final esquema = Theme.of(context).colorScheme;

    return ListTile(
      leading: Checkbox(
        value: pagado,
        onChanged: cerrado ? null : (_) => _alternarPago(context, ref),
        shape: const CircleBorder(),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              gasto.nombre,
              style: TextStyle(
                decoration: pagado ? TextDecoration.lineThrough : null,
                color: pagado ? esquema.onSurfaceVariant : null,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!gasto.editable) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: gasto.origen == OrigenGasto.transporte
                  ? 'Lo calcula el calendario de transporte'
                  : 'Lo gestiona el módulo de deudas',
              child: Icon(
                Icons.auto_awesome,
                size: 14,
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        parcial
            ? '${gasto.categoria.etiqueta} · abonado ${Formato.dinero(gasto.montoPagado)}'
            : gasto.categoria.etiqueta,
        style: TextStyle(
          fontSize: 12.5,
          color: parcial ? Tema.pendiente : esquema.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formato.dinero(gasto.monto),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: pagado ? esquema.onSurfaceVariant : null,
            ),
          ),
          if (parcial)
            Text(
              'falta ${Formato.dinero(gasto.saldoPendiente)}',
              style: const TextStyle(fontSize: 11, color: Tema.pendiente),
            ),
        ],
      ),
      onTap: cerrado ? null : () => _menuGasto(context, ref),
    );
  }

  Future<void> _alternarPago(BuildContext context, WidgetRef ref) async {
    final controlador = ref.read(mesProvider.notifier);
    try {
      if (gasto.estado == EstadoGasto.pagado) {
        await controlador.marcarPendiente(gasto.id);
      } else {
        await controlador.marcarPagado(gasto.id);
      }
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _menuGasto(BuildContext context, WidgetRef ref) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                gasto.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(Formato.dinero(gasto.monto)),
            ),
            const Divider(height: 1),
            if (gasto.estado != EstadoGasto.pagado)
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Abonar una parte'),
                subtitle: const Text('Suma a lo que ya has pagado'),
                onTap: () => Navigator.pop(context, 'abonar'),
              ),
            // Corregir sustituye la cifra en vez de sumarla: es la vía para deshacer un pago
            // apuntado por error o ajustarlo cuando no se pagó el total.
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Corregir lo pagado'),
              subtitle: Text(
                gasto.montoPagado > 0
                    ? 'Ahora figura ${Formato.dinero(gasto.montoPagado)}'
                    : 'Ahora figura como no pagado',
              ),
              onTap: () => Navigator.pop(context, 'corregir'),
            ),
            if (gasto.editable)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Tema.negativo),
                title: const Text(
                  'Eliminar',
                  style: TextStyle(color: Tema.negativo),
                ),
                onTap: () => Navigator.pop(context, 'eliminar'),
              ),
          ],
        ),
      ),
    );

    if (!context.mounted || accion == null) return;

    if (accion == 'eliminar') {
      try {
        await ref.read(mesProvider.notifier).eliminarGasto(gasto.id);
      } on ErrorApi catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.mensaje)));
        }
      }
      return;
    }

    if (accion == 'corregir') {
      final monto = await _pedirCorreccion(context);
      if (monto == null || !context.mounted) return;
      try {
        await ref.read(mesProvider.notifier).corregirPago(gasto.id, monto);
      } on ErrorApi catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.mensaje)));
        }
      }
      return;
    }

    if (accion == 'abonar') {
      final importe = await _pedirImporte(context);
      if (importe == null || !context.mounted) return;
      try {
        await ref.read(mesProvider.notifier).abonar(gasto.id, importe);
      } on ErrorApi catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.mensaje)));
        }
      }
    }
  }

  /// Pide la cifra real pagada, con accesos rápidos a los dos casos habituales: no se pagó
  /// nada o se pagó el total.
  Future<double?> _pedirCorreccion(BuildContext context) async {
    final controlador = TextEditingController(
      text: gasto.montoPagado == 0 ? '' : gasto.montoPagado.round().toString(),
    );

    return showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Corregir lo pagado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${gasto.nombre} vale ${Formato.dinero(gasto.monto)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
              ),
              decoration: const InputDecoration(
                prefixText: r'$ ',
                labelText: 'Cuánto has pagado en realidad',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('No he pagado nada'),
                  onPressed: () => Navigator.pop(contexto, 0.0),
                ),
                ActionChip(
                  label: const Text('Pagué todo'),
                  onPressed: () => Navigator.pop(contexto, gasto.monto),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final valor = double.tryParse(
                controlador.text.replaceAll('.', ''),
              );
              Navigator.pop(contexto, valor);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<double?> _pedirImporte(BuildContext context) async {
    final controlador = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Abonar'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          decoration: InputDecoration(
            prefixText: r'$ ',
            helperText: 'Falta ${Formato.dinero(gasto.saldoPendiente)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final valor = double.tryParse(
                controlador.text.replaceAll('.', ''),
              );
              Navigator.pop(contexto, valor);
            },
            child: const Text('Abonar'),
          ),
        ],
      ),
    );
  }
}

class _SinGastos extends StatelessWidget {
  const _SinGastos();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text('Este mes aún no tiene gastos'),
          const SizedBox(height: 4),
          Text(
            'Añade uno con el botón de abajo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
