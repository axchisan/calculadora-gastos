import '../dominio/plan.dart';
import 'cliente_api.dart';

class RepositorioPlan {
  const RepositorioPlan(this._api);

  final ClienteApi _api;

  Future<Plan> obtener({int meses = 12}) async => Plan.deJson(
    await _api.obtener<Map<String, dynamic>>(
      '/api/plan',
      parametros: {'meses': meses},
    ),
  );

  /// El gasto del día a día al mes; null vuelve a la estimación de la app.
  Future<Plan> fijarGastoDiario(double? monto) async => Plan.deJson(
    await _api.modificar<Map<String, dynamic>>(
      '/api/plan/ajustes',
      cuerpo: {'gastoDiario': monto},
    ),
  );
}
