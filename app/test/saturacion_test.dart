import 'dart:convert';
import 'dart:typed_data';

import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:calculadora_gastos/datos/cliente_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Almacen extends AlmacenSesion {
  @override
  Future<SesionGuardada?> leer() async => null;
  @override
  Future<void> guardar(SesionGuardada sesion) async {}
  @override
  Future<void> borrar() async {}
}

/// Servidor que cuenta cuántas peticiones atiende a la vez y puede rechazar las primeras.
class _Servidor implements HttpClientAdapter {
  int rechazarPrimeras = 0;
  int atendidas = 0;
  int simultaneas = 0;
  int maximoSimultaneas = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? cuerpo,
    Future<void>? cancelacion,
  ) async {
    simultaneas++;
    if (simultaneas > maximoSimultaneas) maximoSimultaneas = simultaneas;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    simultaneas--;
    atendidas++;
    if (atendidas <= rechazarPrimeras) {
      // Lo que responde AWS cuando se pasa el límite de concurrencia de Lambda.
      return ResponseBody.fromString(
        jsonEncode({'message': 'Rate Exceeded.'}),
        429,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Servidor servidor;
  late ClienteApi api;

  setUp(() {
    servidor = _Servidor();
    api = ClienteApi(_Almacen(), dio: Dio()..httpClientAdapter = servidor);
  });

  test('no lanza más de cuatro peticiones a la vez', () async {
    await Future.wait([
      for (var i = 0; i < 12; i++) api.obtener<Map<String, dynamic>>('/api/$i'),
    ]);
    expect(servidor.atendidas, 12);
    expect(servidor.maximoSimultaneas, ClienteApi.maximoSimultaneas);
  });

  test('si el servidor está saturado, reintenta solo', () async {
    servidor.rechazarPrimeras = 2;
    expect(await api.obtener<Map<String, dynamic>>('/api/cuentas'), {
      'ok': true,
    });
    expect(servidor.atendidas, 3);
  });

  test('si sigue saturado, el error lo dice claro', () async {
    servidor.rechazarPrimeras = 99;
    await expectLater(
      api.obtener<Object>('/api/cuentas'),
      throwsA(
        isA<ErrorApi>().having(
          (e) => e.mensaje,
          'mensaje',
          'El servidor está ocupado. Inténtalo de nuevo en un momento.',
        ),
      ),
    );
  });
}
