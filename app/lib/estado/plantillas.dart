import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cliente_api.dart';
import '../datos/repositorio_plantillas.dart';
import '../dominio/modelos.dart';
import 'proveedores.dart';

final repositorioPlantillasProvider = Provider<RepositorioPlantillas>(
  (ref) => RepositorioPlantillas(ref.watch(clienteApiProvider)),
);

class ControladorPlantillas
    extends StateNotifier<AsyncValue<List<PlantillaGasto>>> {
  ControladorPlantillas(this._repositorio) : super(const AsyncValue.loading()) {
    cargar();
  }

  final RepositorioPlantillas _repositorio;

  Future<void> cargar() async {
    state = const AsyncValue.loading();
    await _leer();
  }

  Future<void> refrescar() => _leer();

  Future<void> _leer() async {
    try {
      state = AsyncValue.data(await _repositorio.listar());
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }

  Future<void> crear({
    required String nombre,
    required CategoriaGasto categoria,
    required double monto,
    int? diaVencimiento,
  }) async {
    await _repositorio.crear(
      nombre: nombre,
      categoria: categoria,
      montoDefault: monto,
      diaVencimiento: diaVencimiento,
    );
    await refrescar();
  }

  Future<void> actualizar(
    String id, {
    String? nombre,
    CategoriaGasto? categoria,
    double? monto,
    int? diaVencimiento,
  }) async {
    await _repositorio.actualizar(
      id,
      nombre: nombre,
      categoria: categoria,
      montoDefault: monto,
      diaVencimiento: diaVencimiento,
    );
    await refrescar();
  }

  Future<void> cambiarActivo(String id, bool activo) async {
    await _repositorio.actualizar(id, activo: activo);
    await refrescar();
  }

  Future<void> eliminar(String id) async {
    await _repositorio.eliminar(id);
    await refrescar();
  }
}

final plantillasProvider =
    StateNotifierProvider<
      ControladorPlantillas,
      AsyncValue<List<PlantillaGasto>>
    >((ref) => ControladorPlantillas(ref.watch(repositorioPlantillasProvider)));
