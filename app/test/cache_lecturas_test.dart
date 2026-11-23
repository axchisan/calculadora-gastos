import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:calculadora_gastos/datos/cache_local.dart';
import 'package:calculadora_gastos/datos/cliente_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacén de sesión en memoria: el real usa el llavero del sistema, que no existe en pruebas.
class _AlmacenEnMemoria extends AlmacenSesion {
  SesionGuardada? _sesion;

  @override
  Future<SesionGuardada?> leer() async => _sesion;

  @override
  Future<void> guardar(SesionGuardada sesion) async => _sesion = sesion;

  @override
  Future<void> borrar() async => _sesion = null;
}

/// Servidor falso: responde lo que diga [respuesta] o simula que no hay red.
class _Servidor implements HttpClientAdapter {
  Object respuesta = const {'v': 1};
  bool sinRed = false;
  int peticiones = 0;
  final List<String> metodos = [];

  /// Si se activa, responde con huella y contesta 304 cuando la que llega coincide.
  bool conEtag = false;
  final List<String?> huellasRecibidas = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions opciones,
    Stream<Uint8List>? cuerpo,
    Future<void>? cancelacion,
  ) async {
    peticiones++;
    metodos.add('${opciones.method} ${opciones.path}');
    if (sinRed) {
      throw DioException.connectionError(
        requestOptions: opciones,
        reason: 'sin red',
      );
    }
    final cuerpo = jsonEncode(respuesta);
    if (conEtag) {
      final huella = '"${cuerpo.hashCode}"';
      final recibida = opciones.headers['If-None-Match'] as String?;
      huellasRecibidas.add(recibida);
      if (recibida == huella) {
        return ResponseBody.fromString(
          '',
          304,
          headers: {
            'etag': [huella],
          },
        );
      }
      return ResponseBody.fromString(
        cuerpo,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'etag': [huella],
        },
      );
    }
    return ResponseBody.fromString(
      cuerpo,
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
  late DateTime ahora;

  Future<ClienteApi> crear() async {
    final dio = Dio()..httpClientAdapter = servidor;
    final cliente = ClienteApi(
      _AlmacenEnMemoria(),
      dio: dio,
      cache: await CacheLocal.abrir(),
      reloj: () => ahora,
    );
    await cliente.establecerSesion(
      SesionGuardada(
        accessToken: 'a',
        refreshToken: 'r',
        expiraEn: DateTime(2030),
        usuarioId: 'u1',
        email: 'x@x.co',
        nombre: 'X',
      ),
    );
    return cliente;
  }

  /// Deja terminar la revalidación que corre por detrás.
  Future<void> esperarFondo() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    servidor = _Servidor();
    ahora = DateTime(2026, 11, 22, 16);
    api = await crear();
  });

  test('la primera lectura va al servidor y queda guardada', () async {
    expect(await api.obtener<Map<String, dynamic>>('/api/deudas'), {'v': 1});
    expect(servidor.peticiones, 1);

    // Una app nueva (otra apertura) ya la tiene sin red.
    servidor.sinRed = true;
    final otra = await crear();
    expect(await otra.obtener<Map<String, dynamic>>('/api/deudas'), {'v': 1});
  });

  test(
    'después se sirve lo guardado al instante y se actualiza por detrás',
    () async {
      await api.obtener<Map<String, dynamic>>('/api/deudas');
      servidor.respuesta = const {'v': 2};
      ahora = ahora.add(const Duration(minutes: 5));

      final avisos = <String>[];
      final sub = api.actualizaciones.listen(avisos.add);

      // Devuelve lo guardado sin esperar al servidor...
      expect(await api.obtener<Map<String, dynamic>>('/api/deudas'), {'v': 1});
      await esperarFondo();
      // ...y avisa de que llegó una versión distinta, que ya queda guardada.
      expect(avisos, ['/api/deudas']);
      expect(await api.obtener<Map<String, dynamic>>('/api/deudas'), {'v': 2});
      await sub.cancel();
    },
  );

  test('si el servidor responde lo mismo, no avisa', () async {
    await api.obtener<Map<String, dynamic>>('/api/cuentas');
    ahora = ahora.add(const Duration(minutes: 5));
    final avisos = <String>[];
    final sub = api.actualizaciones.listen(avisos.add);

    await api.obtener<Map<String, dynamic>>('/api/cuentas');
    await esperarFondo();

    expect(avisos, isEmpty);
    await sub.cancel();
  });

  group('con ETag', () {
    setUp(() => servidor.conEtag = true);

    test('revalida con la huella y un 304 conserva lo guardado', () async {
      await api.obtener<Map<String, dynamic>>('/api/deudas');
      ahora = ahora.add(const Duration(minutes: 5));
      final avisos = <String>[];
      final sub = api.actualizaciones.listen(avisos.add);

      expect(await api.obtener<Map<String, dynamic>>('/api/deudas'), {'v': 1});
      await esperarFondo();

      expect(servidor.huellasRecibidas.first, isNull);
      expect(servidor.huellasRecibidas.last, isNotNull);
      expect(avisos, isEmpty);
      // El 304 no borra nada: la siguiente apertura, sin red, sigue teniendo los datos.
      servidor.sinRed = true;
      final otra = await crear();
      expect(await otra.obtener<Map<String, dynamic>>('/api/deudas'), {'v': 1});
      await sub.cancel();
    });

    test('si cambió, llega la versión nueva con su huella', () async {
      await api.obtener<Map<String, dynamic>>('/api/deudas');
      servidor.respuesta = const {'v': 2};
      ahora = ahora.add(const Duration(minutes: 5));
      final avisos = <String>[];
      final sub = api.actualizaciones.listen(avisos.add);

      await api.obtener<Map<String, dynamic>>('/api/deudas');
      await esperarFondo();
      expect(avisos, ['/api/deudas']);

      // Y la huella guardada ya es la nueva: la siguiente revalidación da 304.
      ahora = ahora.add(const Duration(minutes: 5));
      expect(await api.obtener<Map<String, dynamic>>('/api/deudas'), {'v': 2});
      await esperarFondo();
      expect(avisos, ['/api/deudas']);
      expect(
        servidor.huellasRecibidas.last,
        '"${jsonEncode({'v': 2}).hashCode}"',
      );
      await sub.cancel();
    });
  });

  test('no repite la revalidación en ráfaga', () async {
    await api.obtener<Map<String, dynamic>>('/api/cuentas');
    servidor.peticiones = 0;

    for (var i = 0; i < 5; i++) {
      await api.obtener<Map<String, dynamic>>('/api/cuentas');
      await esperarFondo();
    }
    expect(servidor.peticiones, 0);
  });

  test('tras un cambio hecho en la app, lee primero del servidor', () async {
    await api.obtener<Map<String, dynamic>>('/api/meses/1/gastos');
    servidor.respuesta = const {'v': 2};
    ahora = ahora.add(const Duration(seconds: 1));

    await api.publicar<Map<String, dynamic>>('/api/meses/1/gastos', cuerpo: {});

    // Lo guardado es de antes del cambio: no se enseña.
    expect(await api.obtener<Map<String, dynamic>>('/api/meses/1/gastos'), {
      'v': 2,
    });
  });

  test(
    'sin red, después de un cambio, usa lo guardado en vez de fallar',
    () async {
      await api.obtener<Map<String, dynamic>>('/api/meses/1/gastos');
      ahora = ahora.add(const Duration(seconds: 1));
      await api.publicar<Map<String, dynamic>>('/api/x', cuerpo: {});
      servidor.sinRed = true;

      expect(await api.obtener<Map<String, dynamic>>('/api/meses/1/gastos'), {
        'v': 1,
      });
    },
  );

  test('sin nada guardado y sin red, el error llega a la pantalla', () async {
    servidor.sinRed = true;
    expect(
      () => api.obtener<Map<String, dynamic>>('/api/creditos'),
      throwsA(isA<ErrorApi>().having((e) => e.esDeConexion, 'conexión', true)),
    );
  });

  test(
    'avisa al perder la conexión y al recuperarla, y entonces revisa todo',
    () async {
      final estados = <bool>[];
      final avisos = <String>[];
      final s1 = api.cambiosDeRed.listen((r) => estados.add(r.enLinea));
      final s2 = api.actualizaciones.listen(avisos.add);

      servidor.sinRed = true;
      await expectLater(
        api.obtener<Object>('/api/sueldo'),
        throwsA(isA<ErrorApi>()),
      );
      expect(api.red.enLinea, isFalse);
      expect(api.red.sinConexionDesde, ahora);

      servidor.sinRed = false;
      await api.obtener<Object>('/api/sueldo');
      expect(api.red.enLinea, isTrue);
      expect(estados, [false, true]);
      expect(avisos, contains('*'));

      await s1.cancel();
      await s2.cancel();
    },
  );

  test('lo guardado es de cada usuario', () async {
    await api.obtener<Map<String, dynamic>>('/api/deudas');

    final otro = await crear();
    await otro.establecerSesion(
      SesionGuardada(
        accessToken: 'a',
        refreshToken: 'r',
        expiraEn: DateTime(2030),
        usuarioId: 'u2',
        email: 'y@y.co',
        nombre: 'Y',
      ),
    );
    servidor.sinRed = true;
    expect(
      () => otro.obtener<Map<String, dynamic>>('/api/deudas'),
      throwsA(isA<ErrorApi>()),
    );
  });

  test('los parámetros forman parte de la lectura guardada', () async {
    await api.obtener<Map<String, dynamic>>(
      '/api/deudas',
      parametros: {'mes': 11},
    );
    servidor.sinRed = true;
    expect(
      () => api.obtener<Map<String, dynamic>>(
        '/api/deudas',
        parametros: {'mes': 12},
      ),
      throwsA(isA<ErrorApi>()),
    );
    expect(
      await api.obtener<Map<String, dynamic>>(
        '/api/deudas',
        parametros: {'mes': 11},
      ),
      {'v': 1},
    );
  });
}
