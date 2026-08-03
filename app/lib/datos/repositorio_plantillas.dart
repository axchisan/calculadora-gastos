import '../dominio/modelos.dart';
import 'cliente_api.dart';

/// Plantillas de gastos fijos que se copian a cada mes nuevo.
///
/// Modificar una plantilla **no** altera los meses ya creados: subir el arriendo en septiembre
/// no debe reescribir lo que se pagó en agosto.
class RepositorioPlantillas {
  const RepositorioPlantillas(this._api);

  final ClienteApi _api;

  Future<List<PlantillaGasto>> listar() async {
    final datos = await _api.obtener<List<dynamic>>('/api/plantillas');
    return datos
        .map((e) => PlantillaGasto.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PlantillaGasto> crear({
    required String nombre,
    required CategoriaGasto categoria,
    required double montoDefault,
    int? diaVencimiento,
    int? orden,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/plantillas',
      cuerpo: {
        'nombre': nombre,
        'categoria': categoria.codigo,
        'montoDefault': montoDefault,
        'diaVencimiento': ?diaVencimiento,
        'orden': ?orden,
      },
    );
    return PlantillaGasto.deJson(datos);
  }

  Future<PlantillaGasto> actualizar(
    String plantillaId, {
    String? nombre,
    CategoriaGasto? categoria,
    double? montoDefault,
    int? diaVencimiento,
    bool? activo,
    int? orden,
  }) async {
    final datos = await _api.modificar<Map<String, dynamic>>(
      '/api/plantillas/$plantillaId',
      cuerpo: {
        'nombre': ?nombre,
        if (categoria != null) 'categoria': categoria.codigo,
        'montoDefault': ?montoDefault,
        'diaVencimiento': ?diaVencimiento,
        'activo': ?activo,
        'orden': ?orden,
      },
    );
    return PlantillaGasto.deJson(datos);
  }

  /// Deja de copiarla a los meses nuevos sin borrar el histórico.
  Future<void> desactivar(String plantillaId) =>
      _api.publicar<void>('/api/plantillas/$plantillaId/desactivar');

  Future<void> eliminar(String plantillaId) =>
      _api.eliminar('/api/plantillas/$plantillaId');
}
