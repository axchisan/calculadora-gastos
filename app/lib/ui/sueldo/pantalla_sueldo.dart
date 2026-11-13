import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dinero.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/cuentas_y_sueldo.dart';
import '../../estado/cuentas.dart';
import '../../estado/mes.dart';

/// Un sueldo cobrado en dólares: cuánto llega en pesos, cuándo y qué periodo cubre cada pago.
class PantallaSueldo extends ConsumerWidget {
  const PantallaSueldo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuentes = ref.watch(fuentesIngresoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi sueldo')),
      body: fuentes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error is ErrorApi ? error.mensaje : 'No se pudo cargar el sueldo',
          ),
        ),
        data: (lista) => lista.isEmpty
            ? _SinSueldo(alConfigurar: () => _configurar(context, ref))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(fuentesIngresoProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [for (final f in lista) _Fuente(fuente: f)],
                ),
              ),
      ),
    );
  }

  Future<void> _configurar(BuildContext context, WidgetRef ref) async {
    final nombre = TextEditingController();
    final monto = TextEditingController();
    final trm = TextEditingController();
    var inicio = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setState) => AlertDialog(
          title: const Text('Sueldo en dólares'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Empresa'),
                ),
                TextField(
                  controller: monto,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [FormatoDeImporte()],
                  decoration: const InputDecoration(
                    labelText: 'Pago mensual',
                    suffixText: 'USD',
                  ),
                ),
                TextField(
                  controller: trm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [FormatoDeImporte()],
                  decoration: const InputDecoration(labelText: 'TRM de hoy'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Empecé el'),
                  subtitle: Text(Formato.fecha(inicio)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final f = await showDatePicker(
                      context: contexto,
                      initialDate: inicio,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (f != null) setState(() => inicio = f);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final usd = Dinero.interpretar(monto.text);
    final valorTrm = Dinero.interpretar(trm.text);
    if (ok != true || usd == null || valorTrm == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(repositorioCuentasProvider)
          .crearFuente(
            nombre: nombre.text.trim().isEmpty ? 'Sueldo' : nombre.text.trim(),
            montoMensual: usd,
            fechaInicio: inicio,
            medio: MedioCobro.transferencia,
            trm: valorTrm,
          );
      ref.invalidate(fuentesIngresoProvider);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

class _SinSueldo extends StatelessWidget {
  const _SinSueldo({required this.alConfigurar});

  final VoidCallback alConfigurar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_money, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Configura tu sueldo en dólares para ver cuánto te llega en pesos y cuándo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: alConfigurar,
              child: const Text('Configurar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fuente extends ConsumerWidget {
  const _Fuente({required this.fuente});

  final FuenteIngreso fuente;

  /// Lo que dejaría un mes completo por PayPal, con sus costos típicos.
  double get _mesPorPaypal {
    final neto = fuente.montoMensual * (1 - 5.4 / 100) - 0.30;
    return (neto * fuente.trm * (1 - 3.5 / 100) - 3500).floorToDouble();
  }

  double get _mesDirecto => (fuente.montoMensual * fuente.trm).floorToDouble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final usd = Formato.numero(fuente.montoMensual);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fuente.nombre, style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '$usd ${fuente.moneda} al mes desde el '
                  '${Formato.fecha(fuente.fechaInicio)}'
                  '${fuente.fechaFin == null ? '' : ' hasta el ${Formato.fecha(fuente.fechaFin!)}'}',
                  style: tema.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('¿Cómo te llega?', style: tema.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<MedioCobro>(
                  segments: const [
                    ButtonSegment(
                      value: MedioCobro.transferencia,
                      label: Text('Directo al banco'),
                      icon: Icon(Icons.account_balance),
                    ),
                    ButtonSegment(
                      value: MedioCobro.paypal,
                      label: Text('PayPal'),
                      icon: Icon(Icons.public),
                    ),
                  ],
                  selected: {fuente.medio},
                  onSelectionChanged: (s) =>
                      _actualizar(context, ref, medio: s.first),
                ),
                const SizedBox(height: 12),
                _Dato(
                  'Directo al banco',
                  '${Formato.dinero(_mesDirecto)} por mes completo',
                  resaltado: fuente.medio == MedioCobro.transferencia,
                ),
                _Dato(
                  'Por PayPal',
                  '${Formato.dinero(_mesPorPaypal)} por mes completo',
                  resaltado: fuente.medio == MedioCobro.paypal,
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TRM ${Formato.dinero(fuente.trm)} · '
                        '${Formato.fechaCorta(fuente.trmFecha)}',
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _cambiarTrm(context, ref),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Actualizar'),
                    ),
                  ],
                ),
                Text(
                  'Pagan dentro de los primeros ${fuente.diasHabilesPago} días hábiles '
                  'de cada mes por el mes anterior. Por si se demora, se cuentan '
                  '${fuente.diasTolerancia} días hábiles de margen.',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Próximos pagos', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final pago in fuente.proximosPagos)
          _TarjetaPago(pago: pago, moneda: fuente.moneda),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _llevarAlPresupuesto(context, ref),
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Poner estos pagos como sueldo de cada mes'),
        ),
        const SizedBox(height: 8),
        Text(
          'Los montos en pesos son estimados con la TRM guardada. Cuando te llegue cada '
          'pago, corrige el sueldo del mes con lo que de verdad entró.',
          style: tema.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _cambiarTrm(BuildContext context, WidgetRef ref) async {
    final campo = TextEditingController(text: Dinero.paraEditar(fuente.trm));
    final valor = await showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('TRM de hoy'),
        content: TextField(
          controller: campo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const <TextInputFormatter>[FormatoDeImporte()],
          decoration: const InputDecoration(prefixText: r'$ '),
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
    if (valor == null || valor <= 0 || !context.mounted) return;
    await _actualizar(context, ref, trm: valor);
  }

  Future<void> _actualizar(
    BuildContext context,
    WidgetRef ref, {
    MedioCobro? medio,
    double? trm,
  }) async {
    try {
      await ref
          .read(repositorioCuentasProvider)
          .actualizarFuente(fuente.id, medio: medio, trm: trm);
      ref.invalidate(fuentesIngresoProvider);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _llevarAlPresupuesto(BuildContext context, WidgetRef ref) async {
    try {
      final meses = await ref
          .read(repositorioCuentasProvider)
          .llevarAlPresupuesto(fuente.id, pagos: fuente.proximosPagos.length);
      await ref.read(mesProvider.notifier).refrescar();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sueldo actualizado en $meses meses')),
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

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.resaltado = false});

  final String etiqueta;
  final String valor;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: resaltado ? FontWeight.w700 : FontWeight.w400,
      color: resaltado ? null : Theme.of(context).hintColor,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _TarjetaPago extends StatelessWidget {
  const _TarjetaPago({required this.pago, required this.moneda});

  final PagoProyectado pago;
  final String moneda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pago de ${Formato.mesYAnio(pago.mesDePago).toLowerCase()}',
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                Text(
                  Formato.dinero(pago.montoPesos),
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Tema.positivo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cubre del ${Formato.fechaCorta(pago.desde)} al '
              '${Formato.fechaCorta(pago.hasta)} (${pago.diasCubiertos} días)'
              '${pago.prorrateado ? ' · prorrateado' : ''}',
              style: tema.textTheme.bodySmall,
            ),
            Text(
              '${Formato.numero(pago.montoOriginal)} $moneda'
              '${pago.comisiones > 0 ? ' − ${Formato.numero(pago.comisiones)} de comisión' : ''}',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Llega entre el ${Formato.fechaCorta(pago.primerDiaPosible)} y el '
                    '${Formato.fechaCorta(pago.fechaLimite)}; si se demora, hasta el '
                    '${Formato.fechaCorta(pago.fechaTardia)}.',
                    style: tema.textTheme.bodySmall,
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
