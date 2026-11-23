import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/analisis.dart';
import '../../estado/graficas.dart';
import '../../estado/mes.dart';
import '../../estado/movimientos.dart';
import '../../estado/proveedores.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';
import '../mes/pantalla_mes.dart';

/// Análisis: en qué se fue el dinero del mes y cómo van los meses, en frases y dos gráficas
/// que se leen sin hacer cuentas.
class PantallaAnalisis extends ConsumerWidget {
  const PantallaAnalisis({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(movimientosProvider);
    final periodo = ref.watch(periodoProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.lateral, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Análisis', style: textos.headlineSmall),
                  ),
                  TextButton.icon(
                    onPressed: () => PantallaMes.elegirMes(context, ref),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Iconos.desplegar, size: 18),
                    label: Text(
                      Formato.nombreDeMes(periodo.month),
                      style: textos.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: datos.when(
                skipLoadingOnRefresh: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EstadoVacio(
                  icono: Iconos.sinConexion,
                  titulo: 'No se pudo cargar el análisis',
                  texto: e is ErrorApi ? e.mensaje : 'Inténtalo de nuevo',
                  accion: 'Reintentar',
                  alTocarAccion: () => ref.invalidate(movimientosProvider),
                ),
                data: (m) => _Contenido(analisis: AnalisisDelMes(m)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.analisis});

  final AnalisisDelMes analisis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serie = ref.watch(evolucionProvider).valueOrNull;
    final barras = serie == null
        ? const <BarraMes>[]
        : AnalisisDelMes.mesAMes(serie, analisis.movimientos.periodo);
    final ancho = Pantalla.esEscritorio(context) ? 680.0 : double.infinity;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(clienteApiProvider).revisarTodo();
        await ref
            .refresh(movimientosProvider.future)
            .catchError((_) => analisis.movimientos);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lateral,
              Espacio.m,
              Espacio.lateral,
              48,
            ),
            children: [
              if (analisis.frases.isNotEmpty) _Frases(analisis: analisis),
              _EnQueSeFue(analisis: analisis),
              if (barras.length > 1) _MesAMes(barras: barras),
            ],
          ),
        ),
      ),
    );
  }
}

class _Frases extends StatelessWidget {
  const _Frases({required this.analisis});

  final AnalisisDelMes analisis;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final negrita = TextStyle(fontWeight: FontWeight.w700, color: c.tinta);
    final frases = analisis.frases;

    return Panel(
      child: Column(
        children: [
          for (var i = 0; i < frases.length; i++) ...[
            if (i > 0) const SizedBox(height: Espacio.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconoCaja(Iconos.deCategoria(frases[i].categoria), tamano: 34),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: frases[i].antes),
                          if (frases[i].destacado != null) ...[
                            TextSpan(text: frases[i].destacado, style: negrita),
                            TextSpan(
                              text: ' (${Formato.pesos(frases[i].monto)})',
                            ),
                          ] else
                            TextSpan(
                              text: Formato.pesos(frases[i].monto),
                              style: negrita,
                            ),
                          TextSpan(text: frases[i].despues),
                        ],
                      ),
                      style: textos.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EnQueSeFue extends StatelessWidget {
  const _EnQueSeFue({required this.analisis});

  final AnalisisDelMes analisis;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final cats = analisis.porCategoria;

    if (cats.isEmpty) {
      return Seccion(
        titulo: 'En qué se fue',
        child: Panel(
          child: Text(
            'Aún no hay gastos este mes.',
            style: textos.bodyMedium?.copyWith(color: c.tinta2),
          ),
        ),
      );
    }

    final maximo = cats.first.total;
    return Seccion(
      titulo: 'En qué se fue',
      accion: '${Formato.pesos(analisis.totalGastado)} sin deudas',
      child: Panel(
        child: Column(
          children: [
            for (var i = 0; i < cats.length; i++) ...[
              if (i > 0) const SizedBox(height: Espacio.m),
              Semantics(
                label:
                    '${cats[i].categoria.etiqueta}: ${Formato.pesos(cats[i].total)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconos.deCategoria(cats[i].categoria),
                          size: 18,
                          color: c.tinta2,
                        ),
                        const SizedBox(width: Espacio.s),
                        Expanded(
                          child: Text(
                            cats[i].categoria.etiqueta,
                            style: textos.bodyMedium,
                          ),
                        ),
                        Text(
                          Formato.pesos(cats[i].total),
                          style: textos.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: maximo == 0 ? 0 : cats[i].total / maximo,
                        minHeight: 8,
                        backgroundColor: c.superficie2,
                        // La primera, en tinta; las demás, más suaves: el ojo va a la que
                        // más pesa.
                        color: i == 0 ? c.tinta : c.tinta3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MesAMes extends StatelessWidget {
  const _MesAMes({required this.barras});

  final List<BarraMes> barras;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final maximo = barras
        .expand((b) => [b.entro, b.salio])
        .fold<double>(0, math.max);
    final paso = _paso(maximo);
    final hayEstimado = barras.any((b) => b.estimado);

    BarChartRodData barra(
      double valor,
      Color color,
      bool estimado,
    ) => BarChartRodData(
      toY: valor,
      width: 12,
      borderRadius: BorderRadius.circular(4),
      // El mes estimado va solo con el contorno: se ve que no es un dato real.
      color: estimado ? Colors.transparent : color,
      borderSide: estimado
          ? BorderSide(color: color, width: 1.5)
          : BorderSide.none,
      borderDashArray: estimado ? [3, 3] : null,
    );

    Widget leyenda(Color color, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto, style: textos.bodySmall?.copyWith(color: c.tinta2)),
      ],
    );

    return Seccion(
      titulo: 'Mes a mes',
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 190,
              child: Semantics(
                label: [
                  for (final b in barras)
                    '${Formato.nombreDeMes(b.mes.month)}${b.estimado ? ' estimado' : ''}: '
                        'entró ${Formato.pesos(b.entro)}, salió ${Formato.pesos(b.salio)}',
                ].join('. '),
                excludeSemantics: true,
                child: BarChart(
                  BarChartData(
                    maxY: (maximo / paso).ceil() * paso,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: paso,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: c.linea, strokeWidth: 1),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => c.tinta,
                        getTooltipItem: (grupo, _, vara, i) => BarTooltipItem(
                          '${i == 0 ? 'Entró' : 'Salió'}\n${Formato.pesos(vara.toY)}',
                          Tipo.estilo(12, 600, color: c.sobreAcento),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: paso,
                          getTitlesWidget: (v, _) => Text(
                            _compacto(v),
                            style: Tipo.estilo(11, 500, color: c.tinta3),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= barras.length) {
                              return const SizedBox.shrink();
                            }
                            final b = barras[i];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_mesCorto(b.mes)}${b.estimado ? '*' : ''}',
                                style: Tipo.estilo(11, 600, color: c.tinta3),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < barras.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            barra(
                              barras[i].entro,
                              c.positivo,
                              barras[i].estimado,
                            ),
                            barra(barras[i].salio, c.tinta, barras[i].estimado),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Espacio.m),
            Wrap(
              spacing: Espacio.l,
              runSpacing: Espacio.s,
              children: [
                leyenda(c.positivo, 'Entró'),
                leyenda(c.tinta, 'Salió'),
                if (hayEstimado)
                  Text(
                    '* estimado: sueldo y pagos programados',
                    style: textos.bodySmall?.copyWith(color: c.tinta2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static double _paso(double maximo) {
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

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _mesCorto(DateTime f) => _meses[f.month - 1];
