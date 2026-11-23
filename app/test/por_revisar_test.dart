import 'package:calculadora_gastos/core/tema.dart';
import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:calculadora_gastos/datos/cache_local.dart';
import 'package:calculadora_gastos/dominio/detectados.dart';
import 'package:calculadora_gastos/dominio/modelos.dart';
import 'package:calculadora_gastos/estado/detectados.dart';
import 'package:calculadora_gastos/estado/proveedores.dart';
import 'package:calculadora_gastos/ui/detectados/pantalla_por_revisar.dart';
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

/// Cifras y nombres inventados.
Detectado _detectado(Map<String, dynamic> extra) => Detectado.deJson({
  'id': 'd1',
  'origen': 'SMS',
  'monto': -12500,
  'fecha': '2026-08-14',
  'estado': 'PENDIENTE',
  ...extra,
});

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  group('Detectado', () {
    test('pone legible el nombre que el banco escribe en mayúsculas', () {
      final d = _detectado({'contraparte': 'TIENDA LA ESQUINA'});
      expect(d.nombreSugerido, 'Tienda La Esquina');
      expect(
        _detectado({'contraparte': 'Mario Pérez'}).nombreSugerido,
        'Mario Pérez',
      );
      expect(
        _detectado({
          'contraparte': 'X',
          'sugerenciaNombre': 'Mercado',
        }).nombreSugerido,
        'Mercado',
      );
    });

    test('solo está listo para aceptar en bloque si una regla dijo cómo', () {
      expect(
        _detectado({'sugerenciaDestino': 'COMPRA'}).listoParaAceptar,
        isFalse,
      );
      final porRegla = _detectado({
        'monto': 60000,
        'sugerenciaDestino': 'INGRESO',
        'sugerenciaCategoria': 'FAMILIA',
        'sugerenciaNombre': 'Apoyo',
      });
      expect(porRegla.listoParaAceptar, isTrue);
      expect(porRegla.tipoIngresoSugerido, TipoIngreso.familia);
      expect(
        _detectado({
          'sugerenciaDestino': 'ABONO',
          'sugerenciaNombre': 'Nu',
        }).listoParaAceptar,
        isFalse,
      );
      expect(
        _detectado({
          'sugerenciaDestino': 'ABONO',
          'sugerenciaNombre': 'Nu',
          'sugerenciaObjetivo': 'deuda-1',
        }).listoParaAceptar,
        isTrue,
      );
    });

    test('el resumen de la importación se lee en una frase', () {
      final r = ResumenImportacion.deJson({
        'leidos': 70,
        'yaEstaban': 0,
        'pendientes': 23,
        'duplicados': 10,
        'yaRegistrados': 31,
        'descartados': 6,
      });
      expect(
        r.frase,
        '23 por revisar · 41 ya estaban · 6 sin importancia (intereses o retiros)',
      );
      expect(
        ResumenImportacion.deJson({'leidos': 5, 'yaEstaban': 5}).frase,
        '5 ya importados antes',
      );
      expect(
        ResumenImportacion.deJson({'leidos': 2, 'anteriores': 2}).frase,
        '2 de antes de tu último cuadre, sin tocar',
      );
    });
  });

  testWidgets(
    'la bandeja muestra cada movimiento y ofrece aceptar los que ya sabe',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final cache = await CacheLocal.abrir();
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.7;
      addTearDown(tester.view.reset);
      final lista = [
        _detectado({
          'id': 'a',
          'clase': 'COMPRA',
          'contraparte': 'TIENDA LA ESQUINA',
          'hora': '18:05:00',
        }),
        _detectado({
          'id': 'b',
          'origen': 'PDF',
          'monto': 60000,
          'clase': 'TRANSFERENCIA_RECIBIDA',
          'contraparte': 'Nequi',
          'sugerenciaDestino': 'INGRESO',
          'sugerenciaCategoria': 'FAMILIA',
          'sugerenciaNombre': 'Apoyo de Mario',
        }),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cacheProvider.overrideWithValue(cache),
            almacenSesionProvider.overrideWithValue(_AlmacenEnMemoria()),
            detectadosProvider.overrideWith((ref) async => lista),
          ],
          child: MaterialApp(
            theme: Tema.claro(),
            home: const PantallaPorRevisar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('2 movimientos del banco que no están en la app.'),
        findsOneWidget,
      );
      expect(find.text('Tienda La Esquina'), findsOneWidget);
      expect(find.text('Compra con tarjeta · SMS · 18:05'), findsOneWidget);
      expect(find.text('Apoyo de Mario'), findsOneWidget);
      expect(find.text('Registrar el que ya sé cómo'), findsOneWidget);

      await tester.tap(find.text('Tienda La Esquina'));
      await tester.pumpAndSettle();
      expect(find.text('Salió plata'), findsOneWidget);
      expect(find.text('Compra'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Registrar'), findsOneWidget);
      expect(find.text('Ya estaba apuntado'), findsOneWidget);
    },
  );

  testWidgets('sin nada pendiente invita a importar el extracto', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cache = await CacheLocal.abrir();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cacheProvider.overrideWithValue(cache),
          almacenSesionProvider.overrideWithValue(_AlmacenEnMemoria()),
          detectadosProvider.overrideWith((ref) async => const <Detectado>[]),
        ],
        child: MaterialApp(
          theme: Tema.claro(),
          home: const PantallaPorRevisar(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nada por revisar'), findsOneWidget);
    expect(find.text('Importar extracto'), findsOneWidget);
  });
}
