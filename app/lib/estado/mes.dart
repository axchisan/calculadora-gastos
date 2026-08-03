import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cliente_api.dart';
import '../datos/repositorio_meses.dart';
import '../dominio/modelos.dart';
import 'proveedores.dart';

final repositorioMesesProvider = Provider<RepositorioMeses>(
  (ref) =>
      RepositorioMeses(ref.watch(clienteApiProvider), ref.watch(cacheProvider)),
);

/// Periodo que se está viendo. Arranca en el mes en curso.
final periodoProvider = StateProvider<DateTime>((ref) {
  final ahora = DateTime.now();
  return DateTime(ahora.year, ahora.month);
});

/// Contenido de un mes: el resumen y sus gastos, cargados juntos.
class DatosMes {
  const DatosMes({required this.resumen, required this.gastos});

  final ResumenMensual resumen;
  final List<Gasto> gastos;

  /// Gastos que aún no están saldados, primero los más cercanos a vencer.
  List<Gasto> get pendientes {
    final lista = gastos.where((g) => g.estado != EstadoGasto.pagado).toList()
      ..sort((a, b) {
        final va = a.diaVencimiento ?? 99;
        final vb = b.diaVencimiento ?? 99;
        return va.compareTo(vb);
      });
    return lista;
  }

  List<Gasto> get pagados =>
      gastos.where((g) => g.estado == EstadoGasto.pagado).toList();
}

/// Carga el mes indicado y, si aún no existe, lo crea.
///
/// Crear el mes al entrar evita una pantalla vacía con un botón: al abrir la aplicación un día
/// uno, lo natural es encontrar el mes ya montado con los gastos fijos copiados.
class ControladorMes extends StateNotifier<AsyncValue<DatosMes>> {
  ControladorMes(this._repositorio, this._periodo)
    : super(const AsyncValue.loading()) {
    cargar();
  }

  final RepositorioMeses _repositorio;
  final DateTime _periodo;

  String? _mesId;

  String? get mesId => _mesId;

  Future<void> cargar() async {
    state = const AsyncValue.loading();
    try {
      final mes = await _buscarOCrear();
      _mesId = mes.id;
      state = AsyncValue.data(await _cargarDatos(mes.id));
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }

  /// Recarga sin mostrar el indicador de carga, para que la pantalla no parpadee tras una
  /// acción del usuario.
  Future<void> refrescar() async {
    final id = _mesId;
    if (id == null) return cargar();
    try {
      state = AsyncValue.data(await _cargarDatos(id));
    } on ErrorApi catch (e, t) {
      state = AsyncValue.error(e, t);
    }
  }

  Future<void> marcarPagado(String gastoId) async {
    await _repositorio.marcarPagado(gastoId);
    await refrescar();
  }

  Future<void> marcarPendiente(String gastoId) async {
    await _repositorio.marcarPendiente(gastoId);
    await refrescar();
  }

  Future<void> abonar(String gastoId, double importe) async {
    await _repositorio.abonar(gastoId, importe);
    await refrescar();
  }

  Future<void> actualizarIngreso(double ingreso) async {
    final id = _mesId;
    if (id == null) return;
    await _repositorio.actualizarIngreso(id, ingreso);
    await refrescar();
  }

  Future<void> crearGasto({
    required String nombre,
    required CategoriaGasto categoria,
    required double monto,
    int? diaVencimiento,
  }) async {
    final id = _mesId;
    if (id == null) return;
    await _repositorio.crearGasto(
      id,
      nombre: nombre,
      categoria: categoria,
      monto: monto,
      diaVencimiento: diaVencimiento,
    );
    await refrescar();
  }

  /// Cierra el mes: queda como registro histórico y deja de admitir cambios.
  Future<void> cerrar() async {
    final id = _mesId;
    if (id == null) return;
    await _repositorio.cerrar(id);
    await refrescar();
  }

  Future<void> reabrir() async {
    final id = _mesId;
    if (id == null) return;
    await _repositorio.reabrir(id);
    await refrescar();
  }

  Future<void> eliminarGasto(String gastoId) async {
    await _repositorio.eliminarGasto(gastoId);
    await refrescar();
  }

  Future<Mes> _buscarOCrear() async {
    final meses = await _repositorio.listar();
    for (final m in meses) {
      if (m.anio == _periodo.year && m.mes == _periodo.month) return m;
    }
    return _repositorio.crear(anio: _periodo.year, mes: _periodo.month);
  }

  Future<DatosMes> _cargarDatos(String mesId) async {
    // Las dos peticiones son independientes, así que se lanzan a la vez: con el arranque en
    // frío de Lambda, encadenarlas duplicaría la espera.
    final (resumen, gastos) = await (
      _repositorio.resumen(mesId),
      _repositorio.gastos(mesId),
    ).wait;
    return DatosMes(resumen: resumen, gastos: gastos);
  }
}

final mesProvider = StateNotifierProvider<ControladorMes, AsyncValue<DatosMes>>(
  (ref) {
    return ControladorMes(
      ref.watch(repositorioMesesProvider),
      ref.watch(periodoProvider),
    );
  },
);
