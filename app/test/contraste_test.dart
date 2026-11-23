import 'dart:math' as math;
import 'dart:ui';

import 'package:calculadora_gastos/core/tema.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contraste entre dos colores según WCAG.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (nombre, c) in [
    ('claro', Colores.claro),
    ('oscuro', Colores.oscuro),
  ]) {
    group('Tema $nombre', () {
      test(
        'todo color de texto se lee sobre el fondo y las tarjetas (4,5:1)',
        () {
          final textos = {
            'tinta': c.tinta,
            'tinta2': c.tinta2,
            'tinta3': c.tinta3,
            'positivo': c.positivo,
            'negativo': c.negativo,
            'aviso': c.aviso,
          };
          for (final MapEntry(key: n, value: color) in textos.entries) {
            for (final (fondo, valor) in [
              ('fondo', c.fondo),
              ('superficie', c.superficie),
            ]) {
              expect(
                _contraste(color, valor),
                greaterThanOrEqualTo(4.5),
                reason: '$n sobre $fondo',
              );
            }
          }
        },
      );

      test('los avisos se leen sobre su propio fondo', () {
        expect(_contraste(c.aviso, c.avisoFondo), greaterThanOrEqualTo(4.5));
        expect(
          _contraste(c.positivo, c.positivoFondo),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(c.negativo, c.negativoFondo),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }
}
