import 'package:calculadora_gastos/core/tema.dart';
import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:calculadora_gastos/datos/cache_local.dart';
import 'package:calculadora_gastos/dominio/inicio.dart';
import 'package:calculadora_gastos/estado/inicio.dart';
import 'package:calculadora_gastos/estado/proveedores.dart';
import 'package:calculadora_gastos/ui/inicio/pantalla_inicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AlmacenEnMemoria extends AlmacenSesion {
  @override
  Future<SesionGuardada?> leer() async => SesionGuardada(
    accessToken: 'a',
    refreshToken: 'r',
    expiraEn: DateTime(2030),
    usuarioId: 'u1',
    email: 'ana@ejemplo.co',
    nombre: 'Ana María',
  );

  @override
  Future<void> guardar(SesionGuardada sesion) async {}

  @override
  Future<void> borrar() async {}
}

/// Cifras inventadas. Hoy es el 20 de agosto: el mes va del 28 jul al 27 ago.
DatosInicio _datos({double disponible = 60000}) {
  final resumen = <String, dynamic>{
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
    'mesId': 'm1',
    'periodo': '2026-08',
    'cerrado': false,
    'ingresoTotal': 1000000,
    'disponibleHoy': disponible,
    'porCategoria': <dynamic>[],
  };
  return DatosInicio.deJson({
    'hoy': '2026-08-20',
    'periodo': '2026-08',
    'resumen': resumen,
    'cuentas': [
      {
        'id': 'c1',
        'nombre': 'Banco',
        'tipo': 'BANCO',
        'saldo': 60000,
        'saldoAl': '2026-08-20',
        'activa': true,
        'orden': 0,
      },
    ],
    'proximosPagos': [
      {
        'tipo': 'GASTO',
        'id': 'g1',
        'titulo': 'Internet',
        'detalle': 'Gasto fijo · este mes',
        'monto': 80000,
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
        'tipo': 'GASTO',
        'id': 'g2',
        'titulo': 'Tarjeta (corte 15 ago)',
        'detalle': 'Gasto fijo',
        'fecha': '2026-09-04',
        'monto': 200000,
        'ingreso': false,
        'vencido': false,
      },
      {
        'tipo': 'DEUDA',
        'id': 'd1',
        'titulo': 'Préstamo',
        'detalle': 'Pago único',
        'fecha': '2026-09-04',
        'monto': 100000,
        'ingreso': false,
        'vencido': false,
      },
    ],
  });
}

Future<void> _montar(WidgetTester tester, DatosInicio datos) async {
  SharedPreferences.setMockInitialValues({});
  final cache = await CacheLocal.abrir();
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.7;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cacheProvider.overrideWithValue(cache),
        almacenSesionProvider.overrideWithValue(_AlmacenEnMemoria()),
        inicioProvider.overrideWith((ref) async => datos),
      ],
      child: MaterialApp(theme: Tema.claro(), home: const PantallaInicio()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  testWidgets('responde de un vistazo: cuánto hay, qué falta y qué viene', (
    tester,
  ) async {
    await _montar(tester, _datos());

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(find.textContaining('Agosto · 28 jul – 27 ago'), findsOneWidget);
    expect(find.text('Tienes hoy'), findsOneWidget);
    expect(find.text('Cuadra con tus bancos'), findsOneWidget);
    expect(find.text('Faltan 7 días para cerrar el mes'), findsOneWidget);

    // 60.000 − 80.000 del internet, antes de que llegue el sueldo.
    expect(
      find.textContaining('te faltarían \$20.000 hasta que llegue tu sueldo'),
      findsOneWidget,
    );

    expect(find.text('Próximos pagos'), findsOneWidget);
    expect(find.text('Mismo día'), findsNWidgets(2));
    expect(find.text('1–7'), findsOneWidget);
    expect(
      find.textContaining('El 4 sep pagas \$300.000 entre Tarjeta y Préstamo.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Tu sueldo llega entre el 1 y el 7 sep.'),
      findsOneWidget,
    );

    // Entró 1.000.000 y quedan 60.000: salieron 940.000.
    expect(find.text('Gastaste el 94 % de lo que entró.'), findsOneWidget);
    expect(find.text('Mis cuentas'), findsOneWidget);
    expect(find.text('Tu sueldo'), findsOneWidget);
  });

  testWidgets('si no cuadra, dice cuánto y hacia dónde', (tester) async {
    await _montar(tester, _datos(disponible: 45000));
    expect(find.text('Tienes \$15.000 más que la app'), findsOneWidget);
  });
}
