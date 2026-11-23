import 'package:calculadora_gastos/dominio/panorama_deudas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cifras inventadas.
void main() {
  PanoramaDeudas leer({bool conSinPlan = false}) => PanoramaDeudas.deJson({
    'total': 340000,
    'partes': [
      {
        'origen': 'CREDITO',
        'id': 'c1',
        'nombre': 'Banco Uno',
        'tipo': 'CREDITO',
        'saldo': 200000,
        'progreso': 0.3333,
        'terminaEn': '2026-10',
        'proximoPago': '2026-09-10',
        'proximoMonto': 103000,
        'cuotas': 'Cuota 2 de 3',
        'sinPlan': false,
      },
      {
        'origen': 'DEUDA',
        'id': 'd1',
        'nombre': 'Tío',
        'tipo': 'FAMILIAR',
        'saldo': 90000,
        'progreso': 0,
        'terminaEn': '2026-11',
        'sinPlan': false,
      },
      if (conSinPlan)
        {
          'origen': 'DEUDA',
          'id': 'd2',
          'nombre': 'Amiga',
          'tipo': 'AMIGO',
          'saldo': 40000,
          'progreso': 0,
          'sinPlan': true,
        },
    ],
    'proyeccion': [
      {'mes': '2026-08', 'total': 340000},
      {'mes': '2026-09', 'total': 160000},
      {'mes': '2026-10', 'total': 0},
    ],
    'terminaTodoEn': conSinPlan ? null : '2026-11',
    'saldadas': [
      {'origen': 'DEUDA', 'id': 'd9', 'nombre': 'Vecino'},
    ],
  });

  test('lee las partes, la proyección y las saldadas', () {
    final p = leer();
    expect(p.total, 340000);
    expect(p.partes.first.origen, OrigenDeuda.credito);
    expect(p.partes.first.etiquetaTipo, 'Crédito');
    expect(p.partes.first.proximoPago, DateTime(2026, 9, 10));
    expect(p.partes[1].etiquetaTipo, 'Familia');
    expect(p.proyeccion.map((x) => x.total), [340000, 160000, 0]);
    expect(p.terminaTodoEn, DateTime(2026, 11));
    expect(p.saldadas.single.nombre, 'Vecino');
  });

  test('ordena por fecha de fin y separa las que no tienen plan', () {
    final p = leer(conSinPlan: true);
    expect(p.porFin.map((x) => x.nombre), ['Banco Uno', 'Tío']);
    expect(p.sinPlan.single.nombre, 'Amiga');
    expect(p.terminaTodoEn, isNull);
  });
}
