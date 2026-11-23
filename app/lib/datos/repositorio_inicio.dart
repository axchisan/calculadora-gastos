import '../dominio/inicio.dart';
import 'cliente_api.dart';

/// La pantalla de Inicio en una sola petición: resumen del mes, cuentas y próximos pagos.
class RepositorioInicio {
  const RepositorioInicio(this._api);

  final ClienteApi _api;

  Future<DatosInicio> obtener() async => DatosInicio.deJson(
    await _api.obtener<Map<String, dynamic>>('/api/inicio'),
  );
}
