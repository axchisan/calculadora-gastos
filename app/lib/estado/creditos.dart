import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/repositorio_creditos.dart';
import '../dominio/credito.dart';
import 'proveedores.dart';

final repositorioCreditosProvider = Provider<RepositorioCreditos>(
  (ref) => RepositorioCreditos(ref.watch(clienteApiProvider)),
);

/// Los créditos del usuario con su estado.
final creditosProvider = FutureProvider<List<Credito>>(
  (ref) => ref.watch(repositorioCreditosProvider).listar(),
);

/// El cuadro completo de un crédito.
final cuadroProvider = FutureProvider.family<List<CuotaCredito>, String>(
  (ref, creditoId) => ref.watch(repositorioCreditosProvider).cuotas(creditoId),
);

/// Lo que se le pide al simulador: cuánto se abona y qué se hace con el ahorro.
class PeticionDeSimulacion {
  const PeticionDeSimulacion({
    required this.creditoId,
    required this.abono,
    required this.modo,
  });

  final String creditoId;
  final double abono;
  final ModoDeAbono modo;

  @override
  bool operator ==(Object other) =>
      other is PeticionDeSimulacion &&
      other.creditoId == creditoId &&
      other.abono == abono &&
      other.modo == modo;

  @override
  int get hashCode => Object.hash(creditoId, abono, modo);
}

/// Qué pasaría si se abonara de más.
final simulacionProvider =
    FutureProvider.family<SimulacionAbono, PeticionDeSimulacion>((
      ref,
      peticion,
    ) {
      return ref
          .watch(repositorioCreditosProvider)
          .simular(
            peticion.creditoId,
            abono: peticion.abono,
            modo: peticion.modo,
          );
    });

/// Marca una cuota como pagada, o la devuelve a pendiente.
final marcarCuotaProvider =
    Provider<Future<void> Function(String, {required bool pagada})>((ref) {
      return (cuotaId, {required bool pagada}) async {
        await ref
            .read(repositorioCreditosProvider)
            .marcarCuota(cuotaId, pagada: pagada);
        // Cambia el saldo, el estado y el cuadro entero.
        ref.invalidate(creditosProvider);
        ref.invalidate(cuadroProvider);
      };
    });
