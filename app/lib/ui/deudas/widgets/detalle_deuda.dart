import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../datos/cliente_api.dart';
import '../../../datos/repositorio_deudas.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/deudas.dart';
import '../../../estado/mes.dart';

/// Detalle de una deuda con su historial de abonos.
class DetalleDeuda extends ConsumerStatefulWidget {
  const DetalleDeuda({required this.deuda, super.key});

  final Deuda deuda;

  @override
  ConsumerState<DetalleDeuda> createState() => _DetalleDeudaState();
}

class _DetalleDeudaState extends ConsumerState<DetalleDeuda> {
  late Future<List<AbonoDeuda>> _abonos;

  @override
  void initState() {
    super.initState();
    _abonos = ref.read(deudasProvider.notifier).abonos(widget.deuda.id);
  }

  @override
  Widget build(BuildContext context) {
    final deuda = widget.deuda;
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deuda.acreedor,
                      style: textos.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
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
                    style: textos.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: deuda.activa ? Tema.negativo : Tema.positivo,
                    ),
                  ),
                  Text(
                    '${deuda.porcentajePagado.toStringAsFixed(0)}% pagado',
                    style: textos.labelSmall,
                  ),
                ],
              ),
            ],
          ),

          if (deuda.tasaInteresMensual != null &&
              deuda.tasaInteresMensual! > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Tema.pendiente.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 18,
                    color: Tema.pendiente,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Al ${deuda.tasaInteresMensual}% mensual, este saldo genera '
                      '${Formato.dinero(deuda.interesMensualEstimado ?? 0)} de interés '
                      'cada mes que no lo pagues.',
                      style: textos.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          if (deuda.activa)
            FilledButton.icon(
              onPressed: () => _abonar(context),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Registrar un abono'),
            ),

          const SizedBox(height: 24),
          Text('Historial', style: textos.titleSmall),
          const SizedBox(height: 8),

          FutureBuilder<List<AbonoDeuda>>(
            future: _abonos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final abonos = snapshot.data ?? const [];
              if (abonos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Aún no has abonado nada',
                    style: textos.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final abono in abonos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.arrow_downward,
                        color: Tema.positivo,
                        size: 20,
                      ),
                      title: Text(Formato.dinero(abono.monto)),
                      subtitle: Text(
                        abono.nota ?? Formato.fecha(abono.fecha),
                        style: textos.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Eliminar y devolver al saldo',
                        onPressed: () => _eliminarAbono(context, abono.id),
                      ),
                    ),
                ],
              );
            },
          ),

          const Divider(height: 32),
          TextButton.icon(
            onPressed: () => _eliminarDeuda(context),
            icon: const Icon(Icons.delete_outline, color: Tema.negativo),
            label: const Text(
              'Eliminar esta deuda',
              style: TextStyle(color: Tema.negativo),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abonar(BuildContext context) async {
    final campo = TextEditingController();
    var imputarAlMes = true;

    final resultado = await showDialog<(double, bool)>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setEstado) => AlertDialog(
          title: const Text('Registrar abono'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: campo,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  helperText: 'Debes ${Formato.dinero(widget.deuda.saldo)}',
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: imputarAlMes,
                onChanged: (v) => setEstado(() => imputarAlMes = v ?? true),
                title: const Text('Descontar del mes actual'),
                subtitle: const Text(
                  'Si lo desmarcas, solo baja la deuda',
                  style: TextStyle(fontSize: 11.5),
                ),
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
                final valor = double.tryParse(campo.text.replaceAll('.', ''));
                if (valor != null) {
                  Navigator.pop(contexto, (valor, imputarAlMes));
                }
              },
              child: const Text('Abonar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == null || !context.mounted) return;

    final mesId = ref.read(mesProvider).valueOrNull?.resumen.mesId;
    await _ejecutar(context, () async {
      await ref
          .read(deudasProvider.notifier)
          .abonar(
            widget.deuda.id,
            monto: resultado.$1,
            mesId: resultado.$2 ? mesId : null,
          );
      if (context.mounted) Navigator.pop(context);
    });
  }

  Future<void> _eliminarAbono(BuildContext context, String abonoId) async {
    await _ejecutar(context, () async {
      await ref.read(deudasProvider.notifier).eliminarAbono(abonoId);
      if (context.mounted) Navigator.pop(context);
    });
  }

  Future<void> _eliminarDeuda(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Eliminar la deuda'),
        content: const Text(
          'Se borra junto con todo su historial de abonos. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tema.negativo),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!(confirmado ?? false) || !context.mounted) return;

    await _ejecutar(context, () async {
      await ref.read(deudasProvider.notifier).eliminar(widget.deuda.id);
      if (context.mounted) Navigator.pop(context);
    });
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
