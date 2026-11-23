import 'package:calculadora_gastos/dominio/inicio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cifras inventadas: lo que se comprueba es la lectura de `GET /api/inicio`.
void main() {
  Map<String, dynamic> respuesta({Map<String, dynamic>? resumen}) => {
    'hoy': '2026-08-20',
    'periodo': '2026-08',
    'resumen': ?resumen,
    'cuentas': [
      {
        'id': 'c1',
        'nombre': 'Banco',
        'tipo': 'BANCO',
        'saldo': 120000.5,
        'saldoAl': '2026-08-19',
        'activa': true,
        'orden': 0,
      },
      {
        'id': 'c2',
        'nombre': 'Cerrada',
        'tipo': 'BANCO',
        'saldo': 9000,
        'saldoAl': '2026-01-01',
        'activa': false,
        'orden': 1,
      },
    ],
    'proximosPagos': [
      {
        'tipo': 'GASTO',
        'id': 'g1',
        'titulo': 'Celular',
        'detalle': 'Gasto fijo · este mes',
        'monto': 50000,
        'ingreso': false,
        'vencido': false,
      },
      {
        'tipo': 'SUELDO',
        'id': 's1',
        'titulo': 'Sueldo Empresa',
        'detalle': '1.000,00 USD',
        'fecha': '2026-09-01',
        'fechaHasta': '2026-09-07',
        'monto': 3900000,
        'ingreso': true,
        'vencido': false,
      },
      {
        'tipo': 'ALGO_NUEVO',
        'id': 'x',
        'titulo': 'Desconocido',
        'fecha': '2026-09-02',
        'monto': 1,
      },
    ],
  };

  test('lee los próximos pagos con y sin fecha', () {
    final datos = DatosInicio.deJson(respuesta());

    expect(datos.periodo, DateTime(2026, 8));
    expect(datos.resumen, isNull);
    expect(datos.proximosPagos, hasLength(3));

    final celular = datos.proximosPagos[0];
    expect(celular.fecha, isNull);
    expect(celular.tipo, TipoProximoPago.gasto);

    final sueldo = datos.proximosPagos[1];
    expect(sueldo.tipo, TipoProximoPago.sueldo);
    expect(sueldo.ingreso, isTrue);
    expect(sueldo.fechaHasta, DateTime(2026, 9, 7));
  });

  test('un tipo que la app no conoce no rompe la lectura', () {
    final raro = DatosInicio.deJson(respuesta()).proximosPagos[2];
    expect(raro.tipo, TipoProximoPago.gasto);
    expect(raro.detalle, '');
  });

  test('el dinero real suma solo las cuentas activas', () {
    expect(DatosInicio.deJson(respuesta()).dineroReal, 120000.5);
  });
}
