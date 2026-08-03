import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/modelos.dart';
import '../../estado/deudas.dart';
import '../../estado/graficas.dart';
import '../../estado/mes.dart';

/// Gráficas del estado financiero.
class PantallaGraficas extends ConsumerWidget {
  const PantallaGraficas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesProvider);
    final evolucion = ref.watch(evolucionProvider);
    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 760.0
        : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('Gráficas')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              mes.when(
                loading: () => const _Cargando(),
                error: (e, _) => _Aviso(
                  mensaje: e is ErrorApi
                      ? e.mensaje
                      : 'No se pudo cargar el mes',
                ),
                data: (d) => _DistribucionGasto(resumen: d.resumen),
              ),
              const SizedBox(height: 20),
              evolucion.when(
                loading: () => const _Cargando(),
                error: (e, _) => _Aviso(
                  mensaje: e is ErrorApi
                      ? e.mensaje
                      : 'No se pudo cargar el histórico',
                ),
                data: (serie) => _Evolucion(serie: serie),
              ),
              const SizedBox(height: 20),
              _AvanceDeudas(),
            ],
          ),
        ),
      ),
    );
  }
}

/// En qué se va el dinero este mes.
class _DistribucionGasto extends StatelessWidget {
  const _DistribucionGasto({required this.resumen});

  final ResumenMensual resumen;

  /// Paleta estable por categoría: que el color de «Vivienda» no cambie entre meses es lo que
  /// permite comparar dos gráficas de un vistazo.
  static const Map<CategoriaGasto, Color> _colores = {
    CategoriaGasto.vivienda: Color(0xFF00695C),
    CategoriaGasto.alimentacion: Color(0xFF43A047),
    CategoriaGasto.transporte: Color(0xFF1565C0),
    CategoriaGasto.servicios: Color(0xFF6A1B9A),
    CategoriaGasto.suscripciones: Color(0xFFAD1457),
    CategoriaGasto.salud: Color(0xFFD84315),
    CategoriaGasto.educacion: Color(0xFF00838F),
    CategoriaGasto.deporte: Color(0xFFEF6C00),
    CategoriaGasto.herramientas: Color(0xFF4527A0),
    CategoriaGasto.deuda: Color(0xFFC62828),
    CategoriaGasto.ahorro: Color(0xFF2E7D32),
    CategoriaGasto.otro: Color(0xFF546E7A),
  };

  @override
  Widget build(BuildContext context) {
    if (resumen.porCategoria.isEmpty) {
      return const _TarjetaVacia(
        icono: Icons.pie_chart_outline,
        titulo: 'Sin gastos este mes',
        detalle: 'Añade gastos para ver en qué se va tu dinero.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'En qué se va el mes',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  sections: [
                    for (final t in resumen.porCategoria)
                      PieChartSectionData(
                        value: t.total,
                        color: _colores[t.categoria],
                        radius: 42,
                        // Por debajo del 8% la etiqueta no cabe sin solaparse.
                        title: t.porcentaje >= 8
                            ? '${t.porcentaje.toStringAsFixed(0)}%'
                            : '',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            for (final t in resumen.porCategoria)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colores[t.categoria],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.categoria.etiqueta)),
                    Text(
                      Formato.dinero(t.total),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${t.porcentaje.toStringAsFixed(1)}%',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
}

/// Ingresos y gastos mes a mes.
class _Evolucion extends StatelessWidget {
  const _Evolucion({required this.serie});

  final List<ResumenMensual> serie;

  @override
  Widget build(BuildContext context) {
    // Con un solo punto no hay línea que trazar ni tendencia que mostrar.
    if (serie.length < 2) {
      return const _TarjetaVacia(
        icono: Icons.show_chart,
        titulo: 'Aún no hay histórico',
        detalle:
            'Cuando lleves un par de meses registrados, aquí verás cómo evoluciona tu dinero.',
      );
    }

    final esquema = Theme.of(context).colorScheme;
    final maximo = serie
        .map(
          (r) => r.ingresoProyectado > r.gastoTotal
              ? r.ingresoProyectado
              : r.gastoTotal,
        )
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Mes a mes',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maximo * 1.15,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maximo / 3,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: esquema.outlineVariant, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: maximo / 3,
                        getTitlesWidget: (valor, _) => Text(
                          Formato.dineroCompacto(valor),
                          style: TextStyle(
                            fontSize: 9.5,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (valor, _) {
                          final i = valor.toInt();
                          if (i < 0 || i >= serie.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              Formato.nombreDeMes(
                                serie[i].periodo.month,
                              ).substring(0, 3),
                              style: TextStyle(
                                fontSize: 10,
                                color: esquema.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _linea(
                      serie.map((r) => r.ingresoProyectado).toList(),
                      Tema.positivo,
                    ),
                    _linea(
                      serie.map((r) => r.gastoTotal).toList(),
                      Tema.pendiente,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Punto(color: Tema.positivo, texto: 'Ingresos'),
                const SizedBox(width: 20),
                _Punto(color: Tema.pendiente, texto: 'Gastos'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static LineChartBarData _linea(
    List<double> valores,
    Color color,
  ) => LineChartBarData(
    spots: [
      for (var i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i]),
    ],
    isCurved: true,
    curveSmoothness: 0.25,
    color: color,
    barWidth: 2.5,
    dotData: FlDotData(
      show: true,
      getDotPainter: (_, _, _, _) =>
          FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
    ),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
  );
}

/// Cuánto se ha saldado de cada deuda.
class _AvanceDeudas extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(deudasProvider).valueOrNull;
    if (datos == null || datos.activas.isEmpty) {
      return const _TarjetaVacia(
        icono: Icons.check_circle_outline,
        titulo: 'Sin deudas pendientes',
        detalle:
            'Cuando registres una deuda, aquí verás cuánto llevas saldado.',
      );
    }

    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avance de las deudas',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            for (final deuda in datos.activas)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deuda.acreedor,
                            style: const TextStyle(fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          Formato.dinero(deuda.saldo),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Tema.negativo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: (deuda.porcentajePagado / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: esquema.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation(Tema.positivo),
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
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icono, size: 36, color: esquema.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(titulo, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Card(
    child: SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Tema.pendiente),
          const SizedBox(width: 12),
          Expanded(child: Text(mensaje)),
        ],
      ),
    ),
  );
}
