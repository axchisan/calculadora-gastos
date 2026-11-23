import 'dart:convert';
import 'dart:typed_data';

import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:calculadora_gastos/datos/cache_local.dart';
import 'package:calculadora_gastos/datos/cliente_api.dart';
import 'package:calculadora_gastos/estado/autenticacion.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AlmacenEnMemoria extends AlmacenSesion {
  _AlmacenEnMemoria(this._sesion);

  SesionGuardada? _sesion;

  @override
  Future<SesionGuardada?> leer() async => _sesion;

  @override
  Future<void> guardar(SesionGuardada sesion) async => _sesion = sesion;

  @override
  Future<void> borrar() async => _sesion = null;
}

/// Un servidor que ya no acepta ni el token ni el de refresco.
class _SinPermiso implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? cuerpo,
    Future<void>? cancelacion,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'error': 'no_autenticado',
      'mensaje': 'Se requiere iniciar sesión',
    }),
    401,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'si la sesión no se puede renovar, se cierra y la app vuelve al login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cache = await CacheLocal.abrir();
      final cliente = ClienteApi(
        _AlmacenEnMemoria(
          SesionGuardada(
            accessToken: 'a',
            refreshToken: 'r',
            expiraEn: DateTime(2030),
            usuarioId: 'u1',
            email: 'x@x.co',
            nombre: 'X',
          ),
        ),
        dio: Dio()..httpClientAdapter = _SinPermiso(),
        cache: cache,
      );
      final controlador = ControladorSesion(cliente, cache);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controlador.state, isA<SesionAbierta>());

      await expectLater(
        cliente.obtener<Object>('/api/inicio'),
        throwsA(isA<SesionExpirada>()),
      );
      expect(controlador.state, isA<SesionCerrada>());
      expect(cliente.haySesion, isFalse);
    },
  );
}
