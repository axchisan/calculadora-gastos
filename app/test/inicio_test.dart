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

  group('lo que se lee en Inicio', () {
    Map<String, dynamic> resumen(double disponible) => {
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
        'ingresoTotal',
        'patrimonioNeto',
        'porcentajeComprometido',
        'saldoProyectado',
      ])
        k: 0,
      'deudasSinCuota': 0,
      'mesId': 'm1',
      'periodo': '2026-08',
      'cerrado': false,
      'disponibleHoy': disponible,
      'porCategoria': <dynamic>[],
    };

    Map<String, dynamic> pago(
      String titulo,
      double monto, {
      String? fecha,
      bool ingreso = false,
      bool vencido = false,
      String tipo = 'GASTO',
    }) => {
      'tipo': ingreso ? 'SUELDO' : tipo,
      'id': titulo,
      'titulo': titulo,
      'fecha': ?fecha,
      'monto': monto,
      'ingreso': ingreso,
      'vencido': vencido,
    };

    DatosInicio datos({
      double disponible = 120000,
      List<Map<String, dynamic>> pagos = const [],
    }) {
      final j = respuesta(resumen: resumen(disponible));
      j['proximosPagos'] = pagos;
      return DatosInicio.deJson(j);
    }

    test('cuadra si la app y los bancos difieren en menos de mil pesos', () {
      expect(datos(disponible: 119500).cuadra, isTrue);
      final descuadre = datos(disponible: 100000);
      expect(descuadre.cuadra, isFalse);
      expect(descuadre.diferenciaConLaApp, closeTo(20000.5, 0.01));
    });

    test('el mes va del 28 al 27', () {
      final d = datos();
      expect(d.inicioDelMes, DateTime(2026, 7, 28));
      expect(d.finDelMes, DateTime(2026, 8, 27));
      expect(d.diasParaCerrar, 7);
    });

    test('lo que queda hasta el sueldo descuenta lo que vence antes', () {
      final d = datos(
        pagos: [
          pago('Celular', 50000),
          pago('Sueldo', 900000, fecha: '2026-09-01', ingreso: true),
          pago('Seguro', 30000, fecha: '2026-08-30'),
          pago('Tarjeta', 200000, fecha: '2026-09-04'),
        ],
      );
      // 120.000,5 − 50.000 − 30.000; la tarjeta vence después del sueldo.
      expect(d.quedaHastaElSueldo, closeTo(40000.5, 0.01));
      expect(d.pendientesDelMes.map((p) => p.titulo), ['Celular']);
      expect(d.proximoSueldo?.titulo, 'Sueldo');
    });

    test('sin sueldo a la vista, cuenta hasta cerrar el mes', () {
      final d = datos(
        pagos: [
          pago('Agua', 30000, fecha: '2026-08-25'),
          pago('Tarjeta', 200000, fecha: '2026-09-04'),
        ],
      );
      expect(d.quedaHastaElSueldo, closeTo(90000.5, 0.01));
    });

    test('marca los días con dos pagos o más', () {
      final d = datos(
        pagos: [
          pago('Tarjeta', 200000, fecha: '2026-09-04'),
          pago('Préstamo', 150000, fecha: '2026-09-04', tipo: 'DEUDA'),
          pago('Cuota', 40000, fecha: '2026-09-10', tipo: 'CUOTA_CREDITO'),
        ],
      );
      expect(d.pagosJuntos.keys, [DateTime(2026, 9, 4)]);
      expect(d.pagosJuntos.values.first, hasLength(2));
    });

    test('sin cuentas, la cifra es el disponible de la app', () {
      final j = respuesta(resumen: resumen(75000));
      j['cuentas'] = <dynamic>[];
      final d = DatosInicio.deJson(j);
      expect(d.tienesHoy, 75000);
      expect(d.diferenciaConLaApp, isNull);
    });
  });
}
