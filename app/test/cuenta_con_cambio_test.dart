import 'package:calculadora_gastos/dominio/cuentas_y_sueldo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la cuenta trae el saldo al día, el anotado y lo apuntado después', () {
    final c = Cuenta.deJson({
      'id': 'a',
      'nombre': 'Efectivo',
      'tipo': 'EFECTIVO',
      'saldo': 11000,
      'saldoAl': '2026-08-14',
      'activa': true,
      'saldoAnotado': 20000,
      'cambio': -9000,
    });
    expect(c.saldo, 11000);
    expect(c.saldoAnotado, 20000);
    expect(c.cambio, -9000);
  });

  test('una respuesta vieja sin cambio se lee como antes', () {
    final c = Cuenta.deJson({
      'id': 'a',
      'nombre': 'Banco',
      'tipo': 'BANCO',
      'saldo': 5000,
      'saldoAl': '2026-08-14',
      'activa': true,
    });
    expect(c.saldoAnotado, 5000);
    expect(c.cambio, 0);
  });
}
