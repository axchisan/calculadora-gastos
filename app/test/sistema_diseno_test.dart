import 'package:calculadora_gastos/core/formato.dart';
import 'package:calculadora_gastos/core/tema.dart';
import 'package:calculadora_gastos/datos/cache_local.dart';
import 'package:calculadora_gastos/estado/apariencia.dart';
import 'package:calculadora_gastos/ui/comun/componentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _con(Widget hijo, {ThemeData? tema}) => MaterialApp(
  theme: tema ?? Tema.claro(),
  home: Scaffold(body: Center(child: hijo)),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  group('Formato.pesos', () {
    test('redondea y quita los centavos', () {
      expect(Formato.pesos(48250.37), r'$48.250');
      expect(Formato.pesos(2345678.91), r'$2.345.679');
      expect(Formato.pesos(0), r'$0');
    });

    test('lo negativo lleva el signo menos tipográfico delante', () {
      expect(Formato.pesos(-12345.67), r'−$12.346');
    });

    test('menos de un peso no se finge cero', () {
      expect(Formato.pesos(0.78), r'$0,78');
      expect(Formato.pesosConSigno(0.78), r'+$0,78');
    });

    test('con signo solo marca lo que entra', () {
      expect(Formato.pesosConSigno(85000), r'+$85.000');
      expect(Formato.pesosConSigno(-12000), r'−$12.000');
    });
  });

  group('Tema', () {
    test('los dos temas traen sus tokens', () {
      expect(Tema.claro().extension<Colores>(), Colores.claro);
      expect(Tema.oscuro().extension<Colores>(), Colores.oscuro);
      expect(Tema.claro().scaffoldBackgroundColor, Colores.claro.fondo);
      expect(Tema.oscuro().brightness, Brightness.dark);
    });

    test('el oscuro no lleva sombras', () {
      expect(Colores.oscuro.sombra, isEmpty);
      expect(Colores.claro.sombra, isNotEmpty);
    });

    testWidgets('el botón secundario no sale igual que el principal', (
      tester,
    ) async {
      await tester.pumpWidget(
        _con(
          Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Guardar')),
              FilledButton.tonal(onPressed: () {}, child: const Text('Editar')),
            ],
          ),
        ),
      );
      Color fondo(String texto) => tester
          .widget<Material>(
            find
                .ancestor(of: find.text(texto), matching: find.byType(Material))
                .first,
          )
          .color!;
      expect(fondo('Guardar'), Colores.claro.acento);
      expect(fondo('Editar'), Colores.claro.superficie2);
    });

    test('la tipografía es Inter con cifras tabulares', () {
      final estilo = Tema.claro().textTheme.displayLarge!;
      expect(estilo.fontFamily, 'Inter');
      expect(estilo.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(estilo.fontWeight, FontWeight.w700);
    });
  });

  group('Elección de tema', () {
    test('empieza en claro', () async {
      SharedPreferences.setMockInitialValues({});
      final control = ControladorTema(await CacheLocal.abrir());
      expect(control.state, ThemeMode.light);
    });

    test('recuerda lo elegido entre aperturas', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = await CacheLocal.abrir();
      await ControladorTema(cache).elegir(ThemeMode.dark);

      expect(ControladorTema(await CacheLocal.abrir()).state, ThemeMode.dark);
    });

    test('cerrar sesión no borra la preferencia', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = await CacheLocal.abrir();
      await ControladorTema(cache).elegir(ThemeMode.system);
      await cache.limpiar();

      expect(ControladorTema(cache).state, ThemeMode.system);
    });
  });

  group('Componentes', () {
    testWidgets('lo que entra va en verde y con signo; lo que sale, en tinta', (
      tester,
    ) async {
      await tester.pumpWidget(
        _con(
          const Column(
            children: [
              Fila(titulo: 'Sueldo', importe: 85000, importeConSigno: true),
              Fila(titulo: 'Wifi', importe: -40000, importeConSigno: true),
            ],
          ),
        ),
      );

      final entra = tester.widget<Text>(find.text(r'+$85.000'));
      final sale = tester.widget<Text>(find.text(r'−$40.000'));
      expect(entra.style!.color, Colores.claro.positivo);
      expect(sale.style!.color, Colores.claro.tinta);
    });

    testWidgets('el panel de lista separa las filas con una línea', (
      tester,
    ) async {
      await tester.pumpWidget(
        _con(
          Panel.lista(
            filas: const [
              Fila(titulo: 'A'),
              Fila(titulo: 'B'),
              Fila(titulo: 'C'),
            ],
          ),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets(
      'la cifra principal se anuncia completa al lector de pantalla',
      (tester) async {
        await tester.pumpWidget(
          _con(const CifraPrincipal(etiqueta: 'Tienes hoy', valor: 48250.37)),
        );
        expect(find.bySemanticsLabel(r'Tienes hoy $48.250'), findsOneWidget);
      },
    );

    testWidgets('una cifra negativa se pinta en rojo', (tester) async {
      await tester.pumpWidget(
        _con(
          const CifraPrincipal(etiqueta: 'Te quedaría', valor: -12345.67),
          tema: Tema.oscuro(),
        ),
      );
      final rico = tester.widget<Text>(find.byType(Text).last);
      final partes = (rico.textSpan! as TextSpan).children!;
      expect((partes.last as TextSpan).style!.color, Colores.oscuro.negativo);
    });
  });
}
