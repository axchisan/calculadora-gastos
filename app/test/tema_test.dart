import 'package:calculadora_gastos/core/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Botones del tema', () {
    testWidgets('un botón lleno cabe en una fila junto a otro', (tester) async {
      // El tema fijaba el ancho mínimo en infinito para que los botones de los formularios
      // ocuparan toda la línea. El efecto colateral era que dentro de una fila desbordaban, y
      // como las tarjetas recortan su contenido, el botón desaparecía sin error visible: así
      // estuvo semanas el de confirmar un pago detectado.
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.oscuro(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: Card(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Descartar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Y de verdad se ve: dentro de la tarjeta, no recortado fuera de ella.
      final tarjeta = tester.getRect(find.byType(Card));
      final boton = tester.getRect(find.byType(FilledButton));
      expect(boton.right, lessThanOrEqualTo(tarjeta.right));
      expect(boton.left, greaterThanOrEqualTo(tarjeta.left));
      expect(boton.width, greaterThan(0));
    });

    testWidgets('el alto cómodo se mantiene', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.oscuro(),
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Guardar')),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FilledButton)).height, 52);
    });
  });
}
