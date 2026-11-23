import 'package:calculadora_gastos/dominio/analisis.dart';
import 'package:calculadora_gastos/dominio/modelos.dart';
import 'package:calculadora_gastos/dominio/movimientos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cifras inventadas.
void main() {
  Map<String, dynamic> mov(
    String titulo,
    double monto, {
    String tipo = 'COMPRA',
    String categoria = 'ALIMENTACION',
  }) => {
    'tipo': tipo,
    'id': titulo,
    'fecha': '2026-08-10',
    'titulo': titulo,
    'categoria': categoria,
    'monto': monto,
    'cuenta': true,
  };

  AnalisisDelMes analisis(List<Map<String, dynamic>> movimientos) =>
      AnalisisDelMes(
        MovimientosDelMes.deJson({
          'mesId': 'm1',
          'periodo': '2026-08',
          'entro': 0,
          'salio': 0,
          'queda': 0,
          'porPagar': <dynamic>[],
          'movimientos': movimientos,
        }),
      );

  test('agrupa lo gastado por categoría sin contar deudas ni ingresos', () {
    final a = analisis([
      mov('Mercado', -60000),
      mov('Pan', -5000),
      mov('Comida del perro', -30000, categoria: 'MASCOTA'),
      mov('Netflix', -20000, tipo: 'GASTO', categoria: 'SUSCRIPCIONES'),
      mov('Cuota', -100000, tipo: 'CUOTA', categoria: 'DEUDA'),
      mov('Pago a la tía', -50000, tipo: 'ABONO', categoria: 'DEUDA'),
      mov('Tarjeta', -40000, tipo: 'GASTO', categoria: 'DEUDA'),
      mov('Sueldo', 900000, tipo: 'SUELDO', categoria: 'SUELDO'),
      mov('La tía te pagó', 10000, tipo: 'ABONO', categoria: 'COBRO'),
    ]);

    expect(a.porCategoria.map((c) => c.categoria), [
      CategoriaGasto.alimentacion,
      CategoriaGasto.mascota,
      CategoriaGasto.suscripciones,
    ]);
    expect(a.porCategoria.first.total, 65000);
    expect(a.totalGastado, 115000);
    expect(a.pagadoEnDeudas, 190000);
  });

  test('las frases dicen lo importante, con su cifra', () {
    final frases = analisis([
      mov('Mercado', -60000),
      mov('Comida del perro', -30000, categoria: 'MASCOTA'),
      mov('Netflix', -20000, tipo: 'GASTO', categoria: 'SUSCRIPCIONES'),
      mov('Cuota', -100000, tipo: 'CUOTA', categoria: 'DEUDA'),
    ]).frases;

    expect(frases.map((f) => f.categoria), [
      CategoriaGasto.alimentacion,
      CategoriaGasto.mascota,
      CategoriaGasto.suscripciones,
      CategoriaGasto.deuda,
    ]);
    // 60.000 de 110.000: más de la mitad.
    expect(frases.first.despues, ': 55 % de lo que gastaste.');
    expect(frases.last.monto, 100000);
  });

  test('sin gastos no hay frases', () {
    expect(analisis([]).frases, isEmpty);
  });

  test('mes a mes: los reales hasta hoy y el siguiente estimado', () {
    ResumenMensual r(int mes, double ingreso, double disponible) =>
        ResumenMensual.deJson({
          for (final k in [
            'abonosDeuda',
            'ahorroTotal',
            'aporteAhorro',
            'comprasACredito',
            'comprasDelMes',
            'comprasInmediatas',
            'comprometido',
            'cortesTarjetaPagados',
            'cortesTarjetaPendientes',
            'cuotasCreditoPagadas',
            'cuotasCreditoPendientes',
            'cuotasDeudaPendientes',
            'deudaTotal',
            'gastoPagado',
            'gastoPendiente',
            'gastoTotal',
            'ingresoBase',
            'patrimonioNeto',
            'porcentajeComprometido',
            'saldoProyectado',
          ])
            k: 0,
          'deudasSinCuota': 0,
          'mesId': 'm$mes',
          'periodo': '2026-${mes.toString().padLeft(2, '0')}',
          'cerrado': false,
          'ingresoTotal': ingreso,
          'ingresoProyectado': ingreso + 1,
          'comprometidoConCuotas': 777,
          'disponibleHoy': disponible,
          'porCategoria': <dynamic>[],
        });

    final barras = AnalisisDelMes.mesAMes([
      r(9, 300, 100),
      r(7, 100, 10),
      r(8, 200, 50),
      r(10, 999, 0),
      r(11, 1, 1),
    ], DateTime(2026, 8));
    expect(barras.map((b) => b.mes.month), [7, 8, 9]);
    expect(barras[1].salio, 150);
    expect(barras.last.estimado, isTrue);
    expect(barras.last.salio, 777);
  });

  test('mes a mes no enseña los meses de antes de empezar a apuntar gastos', () {
    ResumenMensual r(int mes, double ingreso, double disponible) =>
        ResumenMensual.deJson({
          for (final k in [
            'abonosDeuda',
            'ahorroTotal',
            'aporteAhorro',
            'comprasACredito',
            'comprasDelMes',
            'comprasInmediatas',
            'comprometido',
            'comprometidoConCuotas',
            'cortesTarjetaPagados',
            'cortesTarjetaPendientes',
            'cuotasCreditoPagadas',
            'cuotasCreditoPendientes',
            'cuotasDeudaPendientes',
            'deudaTotal',
            'gastoPagado',
            'gastoPendiente',
            'gastoTotal',
            'ingresoBase',
            'ingresoProyectado',
            'patrimonioNeto',
            'porcentajeComprometido',
            'saldoProyectado',
          ])
            k: 0,
          'deudasSinCuota': 0,
          'mesId': 'm$mes',
          'periodo': '2026-${mes.toString().padLeft(2, '0')}',
          'cerrado': false,
          'ingresoTotal': ingreso,
          'disponibleHoy': disponible,
          'porCategoria': <dynamic>[],
        });

    final barras = AnalisisDelMes.mesAMes([
      r(6, 100, 100),
      r(7, 100, 100),
      r(8, 200, 50),
      r(9, 100, 100),
    ], DateTime(2026, 9));
    // Junio y julio no tienen salidas; septiembre sí se queda aunque no tenga.
    expect(barras.map((b) => b.mes.month), [8, 9]);
  });
}
