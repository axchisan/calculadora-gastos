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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dólar (TRM) ${Formato.dinero(fuente.trm)}',
                            style: tema.textTheme.titleSmall,
                          ),
                          Text(
                            fuente.trmAutomatica
                                ? 'Oficial del ${Formato.fechaCorta(fuente.trmFecha)}. '
                                      'Se actualiza sola cada día con la que publica la '
                                      'Superfinanciera.'
                                : 'Fijada a mano el ${Formato.fechaCorta(fuente.trmFecha)}.',
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fijar a mano',
                      onPressed: () => _cambiarTrm(context, ref),
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Tomar la TRM oficial automáticamente'),
                  value: fuente.trmAutomatica,
                  onChanged: (v) => _actualizar(context, ref, trmAutomatica: v),
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
          _TarjetaPago(pago: pago, fuente: fuente),
        if (fuente.recibidos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Pagos que ya llegaron', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final r in fuente.recibidos)
                  ListTile(
                    dense: true,
                    title: Text(
                      'Pago de ${Formato.mesYAnio(r.mesDePago).toLowerCase()}',
                    ),
                    subtitle: Text(
                      '${Formato.numero(r.montoOriginal)} ${fuente.moneda} · llegó el '
                      '${Formato.fechaCorta(r.fecha)} · a ${Formato.dinero(r.tasaEfectiva)} '
                      'por dólar',
                    ),
                    trailing: Text(Formato.dinero(r.montoPesos)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _llevarAlPresupuesto(context, ref),
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Poner estos pagos como sueldo de cada mes'),
        ),
        const SizedBox(height: 8),
        Text(
          'Los dólares de cada pago son exactos. Los pesos dependen del dólar del día en '
          'que te paguen: hasta entonces se estiman con la TRM de hoy. Cuando llegue, toca '
          '«Ya me llegó» y la app guarda lo real.',
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
    bool? trmAutomatica,
  }) async {
    try {
      await ref
          .read(repositorioCuentasProvider)
          .actualizarFuente(
            fuente.id,
            medio: medio,
            trm: trm,
            trmAutomatica: trmAutomatica,
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

class _TarjetaPago extends ConsumerWidget {
  const _TarjetaPago({required this.pago, required this.fuente});

  final PagoProyectado pago;
  final FuenteIngreso fuente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final moneda = fuente.moneda;
    final recibido = pago.recibido;
    final pesos = recibido?.montoPesos ?? pago.montoPesos;
    final sensibilidad = pago.pesosPorCadaPesoDeTrm * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formato.dinero(pesos),
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Tema.positivo,
                      ),
                    ),
                    Text(
                      recibido != null ? 'Recibido' : 'Estimado',
                      style: tema.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${Formato.numero(pago.montoOriginal)} $moneda por el trabajo del '
              '${Formato.fechaCorta(pago.desde)} al ${Formato.fechaCorta(pago.hasta)}',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            if (recibido != null)
              Text(
                'Llegó el ${Formato.fechaCorta(recibido.fecha)}: te pagaron a '
                '${Formato.dinero(recibido.tasaEfectiva)} por dólar '
                '(${_diferencia(recibido.montoPesos - pago.montoPesos)} frente a lo estimado '
                'con la TRM de hoy).',
                style: tema.textTheme.bodySmall,
              )
            else
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
            Theme(
              data: tema.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(
                  'Cómo se calcula',
                  style: tema.textTheme.labelLarge,
                ),
                children: [
                  for (final t in pago.tramos(fuente.montoMensual))
                    _Linea(
                      t.completo
                          ? '${_mes(t.mes)} completo'
                          : '${_mes(t.mes)}: ${t.dias} de ${t.diasDelMes} días '
                                '× ${Formato.numero(fuente.montoMensual)} ÷ ${t.diasDelMes}',
                      '${Formato.numero(_redondear(t.monto))} $moneda',
                    ),
                  _Linea(
                    'Total en dólares',
                    '${Formato.numero(pago.montoOriginal)} $moneda',
                    fuerte: true,
                  ),
                  if (pago.comisiones > 0)
                    _Linea(
                      'Comisión de ${fuente.medio.etiqueta}',
                      '− ${Formato.numero(pago.comisiones)} $moneda',
                    ),
                  _Linea(
                    '× dólar ${Formato.dinero(fuente.trm)}'
                        '${fuente.descuentoCambioPorcentaje > 0 ? ' − ${Formato.numero(fuente.descuentoCambioPorcentaje)} % de cambio' : ''}',
                    '',
                  ),
                  if (fuente.costoRetiro > 0)
                    _Linea(
                      'Retiro al banco',
                      '− ${Formato.dinero(fuente.costoRetiro)}',
                    ),
                  _Linea(
                    'Te llegan',
                    Formato.dinero(pago.montoPesos),
                    fuerte: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Si el dólar sube o baja \$100, este pago cambia '
                    '${Formato.dinero(sensibilidad)}.',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _registrar(context, ref),
                icon: Icon(
                  recibido == null ? Icons.check : Icons.edit,
                  size: 18,
                ),
                label: Text(
                  recibido == null ? 'Ya me llegó' : 'Corregir lo que llegó',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _redondear(double v) => (v * 100).roundToDouble() / 100;

  static String _mes(DateTime m) {
    final texto = Formato.mesYAnio(m).split(' ').first;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  static String _diferencia(double d) => d.abs() < 1
      ? 'igual'
      : d > 0
      ? '${Formato.dinero(d)} más'
      : '${Formato.dinero(-d)} menos';

  Future<void> _registrar(BuildContext context, WidgetRef ref) async {
    final campo = TextEditingController(
      text: pago.recibido == null
          ? ''
          : Dinero.paraEditar(pago.recibido!.montoPesos),
    );
    var fecha = pago.recibido?.fecha ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setState) => AlertDialog(
          title: Text(
            'Pago de ${Formato.mesYAnio(pago.mesDePago).toLowerCase()}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escribe los pesos que te entraron a la cuenta por los '
                '${Formato.numero(pago.montoOriginal)} ${fuente.moneda}.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: campo,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const <TextInputFormatter>[FormatoDeImporte()],
                decoration: const InputDecoration(
                  labelText: 'Llegaron',
                  prefixText: r'$ ',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('El día'),
                subtitle: Text(Formato.fecha(fecha)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final f = await showDatePicker(
                    context: contexto,
                    initialDate: fecha,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (f != null) setState(() => fecha = f);
                },
              ),
            ],
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
    final pesos = Dinero.interpretar(campo.text);
    if (ok != true || pesos == null || pesos <= 0 || !context.mounted) return;

    try {
      final r = await ref
          .read(repositorioCuentasProvider)
          .registrarPago(
            fuente.id,
            mesDePago: pago.mesDePago,
            montoPesos: pesos,
            fecha: fecha,
          );
      ref.invalidate(fuentesIngresoProvider);
      await ref.read(mesProvider.notifier).refrescar();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Guardado: te pagaron a ${Formato.dinero(r.tasaEfectiva)} por dólar. '
            'Ya es el sueldo de su mes.',
          ),
        ),
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

class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor, {this.fuerte = false});

  final String etiqueta;
  final String valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          const SizedBox(width: 8),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}
