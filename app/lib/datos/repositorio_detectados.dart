import 'dart:convert';
import 'dart:typed_data';

import '../dominio/detectados.dart';
import '../dominio/modelos.dart';
import 'cliente_api.dart';

/// La bandeja de movimientos que llegan del banco.
class RepositorioDetectados {
  const RepositorioDetectados(this._api);

  final ClienteApi _api;

  Future<List<Detectado>> pendientes() async {
    final datos = await _api.obtener<List<dynamic>>('/api/detectados');
    return datos
        .map((e) => Detectado.deJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Detectado> aceptar(
    String id, {
    required DestinoDetectado destino,
    String? descripcion,
    CategoriaGasto? categoria,
    TipoIngreso? tipoIngreso,
    MedioPago? medio,
    String? deudaId,
    bool siempre = false,
  }) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/detectados/$id/aceptar',
      cuerpo: {
        'destino': destino.codigo,
        'descripcion': ?descripcion,
        if (categoria != null) 'categoria': categoria.codigo,
        if (tipoIngreso != null) 'tipoIngreso': tipoIngreso.codigo,
        if (medio != null) 'medio': medio.codigo,
        'deudaId': ?deudaId,
        'siempre': siempre,
      },
    );
    return Detectado.deJson(datos);
  }

  /// Con [siempre], lo siguiente de esa misma contraparte se descarta solo.
  Future<void> descartar(String id, {bool siempre = false}) =>
      _api.publicar<dynamic>(
        '/api/detectados/$id/descartar',
        cuerpo: {'siempre': siempre},
      );

  Future<void> yaRegistrado(String id) =>
      _api.publicar<dynamic>('/api/detectados/$id/ya-registrado', cuerpo: {});

  Future<void> reabrir(String id) =>
      _api.publicar<dynamic>('/api/detectados/$id/reabrir', cuerpo: {});

  Future<ResumenImportacion> importarExtracto(Uint8List pdf) async {
    final datos = await _api.publicar<Map<String, dynamic>>(
      '/api/detectados/extractos',
      cuerpo: {'pdf': base64Encode(pdf)},
    );
    return ResumenImportacion.deJson(datos);
  }
}
