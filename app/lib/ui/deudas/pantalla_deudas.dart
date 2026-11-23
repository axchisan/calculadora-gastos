import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/panorama_deudas.dart';
import '../../estado/creditos.dart';
import '../../estado/deudas.dart';
import '../../estado/proveedores.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';
import '../creditos/pantalla_credito.dart';
import 'widgets/detalle_deuda.dart';
import 'widgets/formulario_deuda.dart';

/// Deudas: cuánto se debe en total, cómo baja y cuándo se termina cada una.
///
/// Junta créditos (con el cuadro del banco) y deudas (tarjetas, préstamos, familia). Antes el
/// total solo sumaba las segundas y un crédito de millones no aparecía en la cifra.
class PantallaDeudas extends ConsumerWidget {
  const PantallaDeudas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(panoramaDeudasProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: datos.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EstadoVacio(
            icono: Iconos.sinConexion,
            titulo: 'No se pudieron cargar las deudas',
            texto: e is ErrorApi ? e.mensaje : 'Inténtalo de nuevo',
            accion: 'Reintentar',
            alTocarAccion: () => ref.invalidate(panoramaDeudasProvider),
          ),
          data: (p) => RefreshIndicator(
            onRefresh: () async {
              ref.read(clienteApiProvider).revisarTodo();
              await ref
                  .refresh(panoramaDeudasProvider.future)
                  .catchError((_) => p);
            },
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Pantalla.esEscritorio(context)
                      ? 680
                      : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Espacio.lateral,
                    Espacio.m,
                    Espacio.lateral,
                    96,
                  ),
                  children: [
                    Text('Deudas', style: textos.headlineSmall),
                    const SizedBox(height: Espacio.xl),
                    if (p.partes.isEmpty)
                      const EstadoVacio(
                        icono: Iconos.listo,
                        titulo: 'No debes nada',
                        texto:
                            'Cuando tengas un crédito, una tarjeta o un préstamo, '
                            'aquí verás cuánto debes y cuándo terminas.',
                      )
                    else ...[
                      _Total(panorama: p),
                      if (p.proyeccion.length > 1) _ComoBaja(panorama: p),
                      _Lista(panorama: p),
                    ],
                    if (p.saldadas.isNotEmpty) _Saldadas(saldadas: p.saldadas),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva deuda',
        onPressed: () => _nuevaDeuda(context, ref),
        child: const Icon(Iconos.anadir),
      ),
    );
  }

  Future<void> _nuevaDeuda(BuildContext context, WidgetRef ref) async {
    final nueva = await showModalBottomSheet<DatosNuevaDeuda>(
      context: context,
      useRootNavigator: true,
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

/// Tonos de la barra y los puntos: del más oscuro (la deuda mayor) al más claro. Sin colores
/// de adorno: el color en esta app significa algo, y aquí solo distingue.
List<Color> _tonos(Colores c) => [
  c.tinta,
  c.tinta2,
  c.tinta3,
  Color.lerp(c.tinta3, c.linea, 0.5)!,
  c.linea,
];

Color _tono(Colores c, int i) {
  final tonos = _tonos(c);
  return tonos[math.min(i, tonos.length - 1)];
}

class _Total extends StatelessWidget {
  const _Total({required this.panorama});

  final PanoramaDeudas panorama;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CifraPrincipal(etiqueta: 'Debes en total', valor: panorama.total),
        const SizedBox(height: Espacio.l),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(
              // Estirada: sin esto cada tramo de color medía cero de alto y la barra no se veía.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < panorama.partes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: math.max(
                      1,
                      (panorama.partes[i].saldo / panorama.total * 1000)
                          .round(),
                    ),
                    child: ColoredBox(color: _tono(c, i)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComoBaja extends StatelessWidget {
  const _ComoBaja({required this.panorama});

  final PanoramaDeudas panorama;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final puntos = panorama.proyeccion;
    final maximo = puntos.map((p) => p.total).reduce(math.max);
    final paso = _pasoEje(maximo);
    final ultimo = puntos.length - 1;

    final porFin = panorama.porFin;
    final sinPlan = panorama.sinPlan;
    final frase = <InlineSpan>[
      if (porFin.isNotEmpty) ...[
        const TextSpan(text: 'Terminas '),
        for (var i = 0; i < porFin.length; i++) ...[
          if (i > 0) TextSpan(text: i == porFin.length - 1 ? ' y ' : ', '),
          TextSpan(text: '${_corto(porFin[i].nombre)} en '),
          TextSpan(
            text: _mesYAnioCorto(porFin[i].terminaEn!),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        const TextSpan(text: '.'),
      ],
      if (sinPlan.isNotEmpty)
        TextSpan(
          text:
              '${porFin.isEmpty ? '' : ' '}${_lista(sinPlan.map((p) => _corto(p.nombre)))} '
              '${sinPlan.length == 1 ? 'no tiene' : 'no tienen'} cuota ni fecha: '
              'añádesela para saber cuándo terminas.',
        ),
    ];

    return Seccion(
      titulo: 'Cómo baja',
      accion: 'si pagas solo las cuotas',
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              child: Semantics(
                label:
                    'La deuda total baja de ${Formato.pesos(puntos.first.total)} '
                    'a ${Formato.pesos(puntos.last.total)} en '
                    '${_mesYAnioCorto(puntos.last.mes)}',
                excludeSemantics: true,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: ultimo.toDouble(),
                    minY: 0,
                    maxY: (maximo / paso).ceil() * paso,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => c.tinta,
                        getTooltipItems: (tocados) => [
                          for (final t in tocados)
                            LineTooltipItem(
                              '${_mesYAnioCorto(puntos[t.x.toInt()].mes)}\n'
                              '${Formato.pesos(t.y)}',
                              Tipo.estilo(12, 600, color: c.sobreAcento),
                            ),
                        ],
                      ),
                    ),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: paso,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: c.linea, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: paso,
                          getTitlesWidget: (v, meta) => Text(
                            _compacto(v),
                            style: Tipo.estilo(11, 500, color: c.tinta3),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: math.max(1, (ultimo / 4).ceil()).toDouble(),
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            final intervalo = math.max(1, (ultimo / 4).ceil());
                            // fl_chart también rotula el último punto aunque no caiga en el
                            // intervalo; pegado al borde, se cortaba.
                            if (i < 0 ||
                                i > ultimo ||
                                v != i.toDouble() ||
                                i % intervalo != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                i == 0 ? 'hoy' : _mesEje(puntos[i].mes),
                                style: Tipo.estilo(11, 500, color: c.tinta3),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        // Escalones y no curva: la deuda baja de golpe el día de cada pago, y
                        // una curva suavizada inventaba valores intermedios (y bajaba de cero).
                        isStepLineChart: true,
                        spots: [
                          for (var i = 0; i < puntos.length; i++)
                            FlSpot(i.toDouble(), puntos[i].total),
                        ],
                        color: c.tinta,
                        barWidth: 2,
                        dotData: FlDotData(
                          checkToShowDot: (spot, _) => spot.x == 0,
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: c.tinta.withValues(alpha: 0.07),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (frase.isNotEmpty) ...[
              const SizedBox(height: Espacio.l),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Iconos.calendario, size: 18, color: c.tinta2),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: frase),
                      style: textos.bodyMedium,
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

  /// Un paso de eje redondo: 500 mil, 1 millón, 2 millones…
  static double _pasoEje(double maximo) {
    if (maximo <= 0) return 1;
    final bruto = maximo / 4;
    final magnitud = math
        .pow(10, (math.log(bruto) / math.ln10).floor())
        .toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (m * magnitud >= bruto) return m * magnitud;
    }
    return 10 * magnitud;
  }

  static String _compacto(double v) {
    if (v == 0) return '0';
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    return '${(v / 1000).round()} mil';
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({required this.panorama});

  final PanoramaDeudas panorama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    return Seccion(
      titulo: 'Tus deudas',
      accion: '${panorama.partes.length}',
      child: Panel.lista(
        filas: [
          for (var i = 0; i < panorama.partes.length; i++)
            _FilaDeuda(
              parte: panorama.partes[i],
              tono: _tono(c, i),
              textos: textos,
            ),
        ],
      ),
    );
  }
}

class _FilaDeuda extends ConsumerWidget {
  const _FilaDeuda({
    required this.parte,
    required this.tono,
    required this.textos,
  });

  final ParteDeuda parte;
  final Color tono;
  final TextTheme textos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final detalle = [
      parte.etiquetaTipo,
      ?parte.cuotas,
      if (parte.sinPlan) 'sin cuota ni fecha',
    ].join(' · ');
    final proximo = parte.proximoPago == null || parte.proximoMonto == null
        ? null
        : '${parte.proximoPago!.day} ${_mesCorto(parte.proximoPago!)} · '
              '${Formato.pesos(parte.proximoMonto!)}';

    return InkWell(
      onTap: () => _abrir(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tono,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.linea),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parte.nombre,
                    style: textos.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(detalle, style: textos.bodySmall),
                  if (parte.progreso > 0) ...[
                    const SizedBox(height: Espacio.s),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: parte.progreso,
                        minHeight: 4,
                        backgroundColor: c.superficie2,
                        color: c.positivo,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Espacio.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Importe(parte.saldo, colorear: false),
                if (proximo != null) ...[
                  const SizedBox(height: 2),
                  Text(proximo, style: textos.bodySmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context, WidgetRef ref) async {
    final navegador = Navigator.of(context);
    try {
      if (parte.origen == OrigenDeuda.credito) {
        final credito = await ref
            .read(repositorioCreditosProvider)
            .obtener(parte.id);
        await navegador.push(
          MaterialPageRoute<void>(
            builder: (_) => PantallaCredito(credito: credito),
          ),
        );
      } else {
        final deudas = await ref.read(repositorioDeudasProvider).listar();
        final deuda = deudas.where((d) => d.id == parte.id).firstOrNull;
        if (deuda == null || !context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (_) => DetalleDeuda(deuda: deuda),
        );
      }
      ref.invalidate(panoramaDeudasProvider);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

class _Saldadas extends StatefulWidget {
  const _Saldadas({required this.saldadas});

  final List<DeudaSaldada> saldadas;

  @override
  State<_Saldadas> createState() => _EstadoSaldadas();
}

class _EstadoSaldadas extends State<_Saldadas> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.l),
      child: Panel(
        relleno: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _abierto = !_abierto),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(Iconos.listo, size: 18, color: c.positivo),
                    const SizedBox(width: Espacio.m),
                    Expanded(
                      child: Text(
                        'Ya pagaste ${widget.saldadas.length} '
                        '${widget.saldadas.length == 1 ? 'deuda' : 'deudas'}',
                        style: textos.titleSmall,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _abierto ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Iconos.desplegar, color: c.tinta3),
                    ),
                  ],
                ),
              ),
            ),
            if (_abierto)
              Padding(
                padding: const EdgeInsets.fromLTRB(46, 0, 16, 14),
                child: Text(
                  widget.saldadas.map((s) => s.nombre).join(' · '),
                  style: textos.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- textos ---

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _mesCorto(DateTime f) => _meses[f.month - 1];

/// «jun 27», para el eje de la gráfica, donde no cabe el año entero.
String _mesEje(DateTime f) =>
    '${_mesCorto(f)} ${(f.year % 100).toString().padLeft(2, '0')}';

/// «feb 2028».
String _mesYAnioCorto(DateTime f) => '${_mesCorto(f)} ${f.year}';

/// Sin lo que va entre paréntesis ni números de operación: «RapiFlex #78 (RapiCredit)» →
/// «RapiFlex».
String _corto(String nombre) => nombre
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'\s*#\S+'), '')
    .trim();

String _lista(Iterable<String> partes) {
  final l = partes.toList();
  if (l.length <= 1) return l.join();
  return '${l.sublist(0, l.length - 1).join(', ')} y ${l.last}';
}
