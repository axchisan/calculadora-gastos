import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/repositorio_cuentas.dart';
import '../dominio/cuentas_y_sueldo.dart';
import 'proveedores.dart';

final repositorioCuentasProvider = Provider<RepositorioCuentas>(
  (ref) => RepositorioCuentas(ref.watch(clienteApiProvider)),
);

/// Las cuentas con su saldo al día: el anotado más lo apuntado después. Por eso se vuelve a
/// pedir también cuando se apunta una compra, un pago, un ingreso o un abono.
final cuentasProvider = FutureProvider<List<Cuenta>>((ref) {
  ref.alActualizarse([
    '/api/cuentas',
    '/api/meses',
    '/api/gastos',
    '/api/sueldo',
    '/api/deudas',
    '/api/creditos',
    '/api/ahorro',
  ], ref.invalidateSelf);
  return ref.watch(repositorioCuentasProvider).listar();
});

/// Suma de los saldos de las cuentas activas: el dinero que de verdad hay hoy.
final dineroRealProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(cuentasProvider)
      .whenData(
        (cuentas) => cuentas
            .where((c) => c.activa)
            .fold<double>(0, (suma, c) => suma + c.saldo),
      );
});

/// Ingresos en otra moneda, con sus próximos pagos.
final fuentesIngresoProvider = FutureProvider<List<FuenteIngreso>>((ref) {
  ref.alActualizarse(['/api/sueldo'], ref.invalidateSelf);
  return ref.watch(repositorioCuentasProvider).fuentes();
});
