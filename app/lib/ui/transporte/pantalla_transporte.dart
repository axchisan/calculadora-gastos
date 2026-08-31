import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dinero.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../datos/repositorio_transporte.dart';
import '../../dominio/modelos.dart';
import '../../estado/mes.dart';
import '../../estado/transporte.dart';
import 'widgets/calendario_mes.dart';
import 'widgets/detalle_dia.dart';
import 'widgets/resumen_transporte.dart';

/// Calendario de transporte del mes.
///
/// Es la pantalla que responde a «¿cuánto voy a gastar en pasajes este mes?», contando los
/// días que realmente hay que desplazarse: descuenta festivos colombianos y fines de semana,
/// permite marcar los días de trabajo remoto y suma el pasaje extra de los días con karate.
class PantallaTransporte extends ConsumerWidget {
  const PantallaTransporte({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoProvider);
    final datos = ref.watch(transporteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transporte'),
        actions: [
          if (datos.hasValue)
            PopupMenuButton<String>(
              onSelected: (opcion) async {
                if (opcion == 'regenerar') {
                  await _confirmarRegenerar(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'regenerar',
                  child: Text('Recalcular desde cero'),
                ),
              ],
            ),
        ],
      ),
      body: datos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(
          mensaje: error is ErrorApi
              ? error.mensaje
              : 'No se pudo cargar el transporte',
          alReintentar: () => ref.read(transporteProvider.notifier).cargar(),
        ),
        data: (d) => _Contenido(datos: d, periodo: periodo),
      ),
    );
  }

  Future<void> _confirmarRegenerar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Recalcular el mes'),
        content: const Text(
          'Se descartan los ajustes que hiciste en el calendario y se vuelve a proponer '
          'desde cero, con los días remotos repartidos automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Recalcular'),
          ),
        ],
      ),
    );

    if (confirmado ?? false) {
      await ref.read(transporteProvider.notifier).regenerar();
    }
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.datos, required this.periodo});

  final DatosTransporte datos;
  final DateTime periodo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 720.0
        : double.infinity;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ResumenTransporteTarjeta(datos: datos),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          Text(
                            Formato.mesYAnio(periodo),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            'Toca un día para cambiarlo',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CalendarioMes(
                      semanas: datos.semanas,
                      alTocarDia: (dia) => _abrirDetalle(context, ref, dia),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: LeyendaCalendario(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _Escenarios(datos: datos),
            const SizedBox(height: 20),
            _Ajustes(datos: datos),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirDetalle(
    BuildContext context,
    WidgetRef ref,
    DiaTransporte dia,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DetalleDia(dia: dia),
    );
  }
}

/// Proyecciones según cuántos días se trabaje desde casa.
///
/// Se muestran las tres porque los días remotos varían de una semana a otra, y conocer el
/// rango es más útil que una cifra única que casi nunca se cumple.
class _Escenarios extends StatelessWidget {
  const _Escenarios({required this.datos});

  final DatosTransporte datos;

  @override
  Widget build(BuildContext context) {
    final e = datos.escenarios;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Según los días remotos',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  'rango ${Formato.dinero(e.rango)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FilaEscenario(
              etiqueta: 'Todo presencial',
              escenario: e.pesimista,
              color: Tema.pendiente,
            ),
            const SizedBox(height: 10),
            _FilaEscenario(
              etiqueta: 'Lo previsto',
              escenario: e.esperado,
              color: Theme.of(context).colorScheme.primary,
              resaltado: true,
            ),
            const SizedBox(height: 10),
            _FilaEscenario(
              etiqueta: 'Más días en casa',
              escenario: e.optimista,
              color: Tema.positivo,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaEscenario extends StatelessWidget {
  const _FilaEscenario({
    required this.etiqueta,
    required this.escenario,
    required this.color,
    this.resaltado = false,
  });

  final String etiqueta;
  final Escenario escenario;
  final Color color;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: resaltado ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Text(
                '${escenario.diasOficina} en oficina · ${escenario.diasRemotos} en casa',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          Formato.dinero(escenario.costoTotal),
          style: TextStyle(
            fontWeight: resaltado ? FontWeight.w700 : FontWeight.w500,
            color: resaltado ? color : null,
          ),
        ),
      ],
    );
  }
}

/// Parámetros del cálculo: tarifa, días de karate y días remotos previstos.
class _Ajustes extends ConsumerWidget {
  const _Ajustes({required this.datos});

  final DatosTransporte datos;

  static const List<String> _iniciales = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = datos.configuracion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajustes',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('Valor del pasaje'),
              trailing: Text(
                Formato.dinero(config.valorPasaje),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => _cambiarPasaje(context, ref, config.valorPasaje),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.percent),
              title: const Text('Comisión por recarga'),
              subtitle: Text(
                config.comisionRecarga > 0
                    ? 'Se apunta sola cada vez que abonas al transporte'
                    : 'Sin comisión configurada',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Text(
                Formato.dinero(config.comisionRecarga),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () =>
                  _cambiarComision(context, ref, config.comisionRecarga),
            ),

            const Divider(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_martial_arts, size: 20),
                      const SizedBox(width: 14),
                      const Text('Días de karate'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var dia = 1; dia <= 7; dia++)
                        FilterChip(
                          label: Text(_iniciales[dia - 1]),
                          selected: config.diasKarate.contains(dia),
                          onSelected: (activo) {
                            final nuevos = Set<int>.from(config.diasKarate);
                            if (activo) {
                              nuevos.add(dia);
                            } else {
                              nuevos.remove(dia);
                            }
                            ref
                                .read(transporteProvider.notifier)
                                .cambiarDiasKarate(nuevos);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.home_work_outlined, size: 20),
                      const SizedBox(width: 14),
                      const Text('Días remotos por semana'),
                      const Spacer(),
                      Text(
                        '${config.diasRemotosPorSemana}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Slider(
                    value: config.diasRemotosPorSemana.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: '${config.diasRemotosPorSemana}',
                    onChanged: (v) {},
                    onChangeEnd: (v) => ref
                        .read(transporteProvider.notifier)
                        .cambiarDiasRemotos(v.round()),
                  ),
                  Text(
                    'Cambiarlo reparte de nuevo los días por el calendario y descarta los '
                    'ajustes manuales.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cambia lo que cobra el sistema de recarga por operación.
  ///
  /// Es fija por recarga, así que recargar de a poco sale más caro. Apuntarla cada vez es lo que
  /// hace visible ese sobrecoste, que de otro modo se pierde.
  Future<void> _cambiarComision(
    BuildContext context,
    WidgetRef ref,
    double actual,
  ) async {
    final controlador = TextEditingController(text: Dinero.paraEditar(actual));

    final valor = await showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Comisión por recarga'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [FormatoDeImporte()],
          decoration: const InputDecoration(
            prefixText: r'$ ',
            helperText:
                'Se apuntará como gasto en cada abono al transporte. '
                'Pon 0 para no apuntarla.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              contexto,
              Dinero.interpretar(controlador.text) ?? 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (valor == null) return;
    try {
      await ref.read(transporteProvider.notifier).cambiarComisionRecarga(valor);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _cambiarPasaje(
    BuildContext context,
    WidgetRef ref,
    double actual,
  ) async {
    final controlador = TextEditingController(text: actual.round().toString());

    final valor = await showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Valor del pasaje'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          decoration: const InputDecoration(
            prefixText: r'$ ',
            helperText: 'Se recalcula el mes con la tarifa nueva',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              contexto,
              double.tryParse(controlador.text.replaceAll('.', '')),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (valor != null && valor >= 0) {
      await ref.read(transporteProvider.notifier).cambiarValorPasaje(valor);
    }
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
