import 'package:calculadora_gastos/core/tema.dart';
import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:calculadora_gastos/datos/cache_local.dart';
import 'package:calculadora_gastos/dominio/plan.dart';
import 'package:calculadora_gastos/estado/plan.dart';
import 'package:calculadora_gastos/estado/proveedores.dart';
import 'package:calculadora_gastos/ui/plan/pantalla_plan.dart';
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
    nombre: 'Ana',
  );

  @override
  Future<void> guardar(SesionGuardada sesion) async {}

  @override
  Future<void> borrar() async {}
}

/// Cifras inventadas.
Map<String, dynamic> _mes(
  String periodo,
  double sobra, {
  bool actual = false,
}) => {
  'periodo': periodo,
  'actual': actual,
  'ingreso': 2000000,
  'ingresoEstimado': true,
  'fijos': 200000,
  'pagos': [
    {
      'origen': 'CREDITO',
      'nombre': 'Cuota 4 · Banco de ejemplo',
      'monto': 300000,
      'fecha': '$periodo-02',
    },
  ],
  'totalPagos': 300000,
  'diario': 400000,
  'sobra': sobra,
};

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  testWidgets('dice cuánto sobra y cuándo llega la meta', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cache = await CacheLocal.abrir();
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final plan = Plan.deJson({
      'gastoDiario': 400000,
      'gastoDiarioEstimado': 400000,
      'gastoDiarioPropio': false,
      'sobraPromedio': 1100000,
      'meses': [
        _mes('2026-08', 20000, actual: true),
        _mes('2026-09', 1100000),
        _mes('2026-10', -50000),
      ],
      'metas': [
        {
          'id': 'm1',
          'nombre': 'Teléfono nuevo',
          'objetivo': 3000000,
          'ahorrado': 750000,
          'faltan': 2250000,
          'tipoAsignacion': 'MONTO_FIJO',
          'valor': 800000,
          'aporteMensual': 800000,
          'aportes': <dynamic>[],
          'alcanzaEn': '2027-01',
          'alcanzaEnConTodo': '2026-12',
        },
      ],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cacheProvider.overrideWithValue(cache),
          almacenSesionProvider.overrideWithValue(_AlmacenEnMemoria()),
          planProvider.overrideWith((ref) async => plan),
        ],
        child: MaterialApp(theme: Tema.claro(), home: const PantallaPlan()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teléfono nuevo'), findsOneWidget);
    expect(find.text('Te faltan \$2.250.000'), findsOneWidget);
    expect(
      find.text('Apartando \$800.000 al mes la tienes en enero de 2027.'),
      findsOneWidget,
    );
    expect(
      find.text('Con todo lo que te sobra: diciembre de 2026.'),
      findsOneWidget,
    );
    // Por defecto no resta el día a día (400.000): 1.100.000 + 400.000.
    expect(find.text('Sobran \$1.500.000'), findsOneWidget);
    expect(find.text('Sobran \$350.000'), findsOneWidget);

    // Con el interruptor encendido sí lo resta.
    await tester.tap(find.text('Restar el día a día'));
    await tester.pumpAndSettle();
    expect(find.text('Sobran \$1.100.000'), findsOneWidget);
    expect(find.text('Faltan \$50.000'), findsOneWidget);
    expect(find.textContaining('lo que falta'), findsOneWidget);
    expect(find.text('Día a día: \$400.000 al mes'), findsOneWidget);
  });

  test('el plan lee los meses y las metas', () {
    final m = MetaPlan.deJson({
      'id': 'x',
      'nombre': 'Viaje',
      'objetivo': 1000000,
      'ahorrado': 250000,
      'faltan': 750000,
      'aportes': [
        {'periodo': '2026-09', 'monto': 250000, 'acumulado': 500000},
      ],
    });
    expect(m.progreso, 0.25);
    expect(m.alcanzaEn, isNull);
    expect(m.aportes.single.periodo, DateTime(2026, 9));
  });
}
