import 'package:calculadora_gastos/dominio/cuentas_y_sueldo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desglose de un pago de Migozz', () {
    final primerPago = PagoProyectado.deJson({
      'mesDePago': '2026-12',
      'desde': '2026-10-23',
      'hasta': '2026-11-30',
      'diasCubiertos': 39,
      'prorrateado': true,
      'montoOriginal': 774.19,
      'comisiones': 0,
      'montoPesos': 2567779,
      'primerDiaPosible': '2026-12-01',
      'fechaLimite': '2026-12-07',
      'fechaTardia': '2026-12-10',
      'mesPresupuestal': '2026-12',
      'recibido': null,
    });

    test('octubre se prorratea por días y noviembre va completo', () {
      final tramos = primerPago.tramos(600);

      expect(tramos, hasLength(2));
      expect(tramos[0].dias, 9);
      expect(tramos[0].diasDelMes, 31);
      expect(tramos[0].monto, closeTo(174.19, 0.01));
      expect(tramos[1].completo, isTrue);
      expect(tramos[1].monto, 600);
    });

    test('cada peso que sube el dólar suma lo que vale el pago en dólares', () {
      expect(primerPago.pesosPorCadaPesoDeTrm, closeTo(774.19, 0.001));
    });
  });
}
