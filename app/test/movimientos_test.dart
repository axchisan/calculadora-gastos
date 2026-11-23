import 'package:calculadora_gastos/dominio/modelos.dart';
import 'package:calculadora_gastos/dominio/movimientos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cifras inventadas.
void main() {
  Map<String, dynamic> mov(
    String titulo,
    String fecha,
    double monto, {
    String tipo = 'COMPRA',
    String categoria = 'ALIMENTACION',
    bool cuenta = true,
    String? notas,
    bool pendiente = false,
  }) => {
    'tipo': tipo,
    'id': titulo,
    'fecha': fecha,
    'titulo': titulo,
    'categoria': categoria,
    'monto': monto,
    'cuenta': cuenta,
    'notas': ?notas,
    if (pendiente) '_pendiente': true,
  };

  MovimientosDelMes datos(List<Map<String, dynamic>> movimientos) =>
      MovimientosDelMes.deJson({
        'mesId': 'm1',
        'periodo': '2026-08',
        'cerrado': false,
        'entro': 1000000,
        'salio': 400000,
        'queda': 600000,
        'porPagar': [
          {
            'id': 'g1',
            'nombre': 'Internet',
            'categoria': 'SERVICIOS',
            'monto': 70000,
            'pendiente': 70000,
          },
        ],
        'movimientos': movimientos,
      });

  test('agrupa por día y el neto no cuenta lo cargado a crédito', () {
    final d = datos([
      mov('Café', '2026-08-10', -5000),
      mov('Zapatos', '2026-08-10', -90000, cuenta: false),
      mov('Pago', '2026-08-10', 20000, tipo: 'INGRESO', categoria: 'TRABAJO'),
      mov('Pan', '2026-08-09', -3000),
    ]);
    final dias = d.porDia();
    expect(dias, hasLength(2));
    expect(dias.first.movimientos, hasLength(3));
    expect(dias.first.neto, 15000);
    expect(dias.last.neto, -3000);
  });

  test('filtra entradas y salidas', () {
    final d = datos([
      mov('Café', '2026-08-10', -5000),
      mov('Pago', '2026-08-09', 20000, tipo: 'INGRESO', categoria: 'TRABAJO'),
    ]);
    expect(
      d
          .porDia(filtro: FiltroMovimientos.entradas)
          .single
          .movimientos
          .single
          .titulo,
      'Pago',
    );
    expect(
      d
          .porDia(filtro: FiltroMovimientos.salidas)
          .single
          .movimientos
          .single
          .titulo,
      'Café',
    );
  });

  test(
    'busca sin importar tildes ni mayúsculas, también en notas y categoría',
    () {
      final d = datos([
        mov('Café con pan', '2026-08-10', -5000),
        mov('Jabón', '2026-08-09', -8000, categoria: 'MASCOTA'),
        mov('Regalo', '2026-08-08', -20000, notas: 'Cumpleaños de Ana'),
      ]);
      expect(
        d.porDia(busqueda: 'CAFE').single.movimientos.single.titulo,
        'Café con pan',
      );
      expect(
        d.porDia(busqueda: 'mascota').single.movimientos.single.titulo,
        'Jabón',
      );
      expect(
        d.porDia(busqueda: 'cumpleanos').single.movimientos.single.titulo,
        'Regalo',
      );
    },
  );

  test('lo apuntado sin conexión se ordena en su día', () {
    final d = datos([
      mov('Nuevo', '2026-08-09', -1000, pendiente: true),
      mov('Café', '2026-08-10', -5000),
      mov('Pan', '2026-08-09', -3000),
    ]);
    expect(d.movimientos.map((m) => m.titulo), ['Café', 'Nuevo', 'Pan']);
    expect(d.movimientos[1].pendiente, isTrue);
  });

  test('cada tipo sabe su categoría o su tipo de ingreso', () {
    final d = datos([
      mov(
        'Préstamo',
        '2026-08-10',
        50000,
        tipo: 'INGRESO',
        categoria: 'PRESTAMO',
      ),
      mov('Cuota', '2026-08-09', -40000, tipo: 'CUOTA', categoria: 'DEUDA'),
      mov('Comida', '2026-08-08', -9000, categoria: 'MASCOTA'),
    ]);
    expect(d.movimientos[0].tipoIngreso, TipoIngreso.prestamo);
    expect(d.movimientos[0].etiquetaCategoria, 'Préstamo');
    expect(d.movimientos[1].etiquetaCategoria, 'Crédito');
    expect(d.movimientos[2].categoriaGasto, CategoriaGasto.mascota);
    expect(d.porPagar.single.categoria, CategoriaGasto.servicios);
  });
}
