import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:calculadora_gastos/core/identificadores.dart';
import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:calculadora_gastos/datos/cache_local.dart';
import 'package:calculadora_gastos/datos/cliente_api.dart';
import 'package:calculadora_gastos/datos/cola_pendientes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AlmacenEnMemoria extends AlmacenSesion {
  SesionGuardada? _sesion;

  @override
  Future<SesionGuardada?> leer() async => _sesion;

  @override
  Future<void> guardar(SesionGuardada sesion) async => _sesion = sesion;

  @override
  Future<void> borrar() async => _sesion = null;
}

/// Servidor falso con una lista de compras en memoria.
class _Servidor implements HttpClientAdapter {
  bool sinRed = false;
  final List<Map<String, dynamic>> compras = [];
  final List<String> registro = [];

  /// Rutas que el servidor rechaza con un 400.
  final Set<String> rechazar = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? cuerpo,
    Future<void>? cancelacion,
  ) async {
    if (sinRed) {
      throw DioException.connectionError(requestOptions: o, reason: 'sin red');
    }
    registro.add('${o.method} ${o.path}');
    if (rechazar.contains(o.path)) {
      return _json({
        'error': 'validacion',
        'mensaje': 'El monto no es válido',
      }, 400);
    }
    if (o.method == 'GET') return _json({'compras': compras}, 200);

    final datos = (o.data as Map).cast<String, dynamic>();
    // Como el backend: el mismo identificador no se crea dos veces.
    if (!compras.any((c) => c['id'] == datos['id'])) compras.add(datos);
    return _json(datos, 201);
  }

  ResponseBody _json(Object datos, int estado) => ResponseBody.fromString(
    jsonEncode(datos),
    estado,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Servidor servidor;
  late ClienteApi api;

  Future<ClienteApi> crear() async {
    final cliente = ClienteApi(
      _AlmacenEnMemoria(),
      dio: Dio()..httpClientAdapter = servidor,
      cache: await CacheLocal.abrir(),
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

  /// Apunta una compra como lo hace el repositorio.
  Future<Map<String, dynamic>> apuntar(String descripcion) {
    final id = nuevoIdentificador();
    final cuerpo = {'id': id, 'descripcion': descripcion, 'monto': 4000};
    return api.publicar<Map<String, dynamic>>(
      '/api/meses/m1/compras',
      cuerpo: cuerpo,
      descripcion: 'Compra · $descripcion',
      sinConexion: Superposicion(
        ruta: '/api/meses/m1/compras',
        campoLista: 'compras',
        datos: {...cuerpo, '_pendiente': true},
      ),
    );
  }

  Future<List<dynamic>> listaVisible() async =>
      (await api.obtener<Map<String, dynamic>>(
            '/api/meses/m1/compras',
          ))['compras']
          as List<dynamic>;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    servidor = _Servidor();
    api = await crear();
    await api.obtener<Object>('/api/meses/m1/compras'); // queda en caché, vacía
  });

  test('sin red, lo apuntado queda en la cola y se ve en la lista', () async {
    servidor.sinRed = true;
    final devuelto = await apuntar('Pan');

    expect(devuelto['_pendiente'], isTrue);
    expect(api.pendientes, hasLength(1));
    expect(api.red.porSubir, 1);

    final lista = await listaVisible();
    expect(lista, hasLength(1));
    expect(lista.first['descripcion'], 'Pan');
    expect(lista.first['_pendiente'], isTrue);
  });

  test('la cola sobrevive a cerrar la app', () async {
    servidor.sinRed = true;
    await apuntar('Pan');

    final otraApertura = await crear();
    expect(otraApertura.pendientes.single.descripcion, 'Compra · Pan');
  });

  test(
    'al volver la red se envía con el mismo identificador y sale de la cola',
    () async {
      servidor.sinRed = true;
      final apuntada = await apuntar('Pan');

      servidor.sinRed = false;
      await api.sincronizar();

      expect(api.pendientes, isEmpty);
      expect(servidor.compras.single['id'], apuntada['id']);
      expect(api.red.porSubir, 0);
    },
  );

  test('reenviar lo que ya había llegado no lo duplica', () async {
    servidor.sinRed = true;
    final apuntada = await apuntar('Pan');
    servidor.sinRed = false;
    // Llegó, pero la respuesta se perdió: la app no se enteró y lo sigue teniendo en cola.
    servidor.compras.add({'id': apuntada['id'], 'descripcion': 'Pan'});

    await api.sincronizar();
    expect(servidor.compras, hasLength(1));
    expect(api.pendientes, isEmpty);
  });

  test('lo que el servidor rechaza queda a la vista con su motivo', () async {
    servidor.sinRed = true;
    await apuntar('Pan');
    servidor
      ..sinRed = false
      ..rechazar.add('/api/meses/m1/compras');

    await api.sincronizar();

    expect(api.pendientes.single.error, 'El monto no es válido');
    expect(api.red.conError, 1);
    expect(api.red.porSubir, 0);
  });

  test(
    'reintentar lo envía otra vez; descartar lo quita de la lista',
    () async {
      servidor.sinRed = true;
      await apuntar('Pan');
      await apuntar('Leche');
      servidor
        ..sinRed = false
        ..rechazar.add('/api/meses/m1/compras');
      await api.sincronizar();
      expect(api.red.conError, 2);

      servidor.rechazar.clear();
      await api.reintentar(api.pendientes.first.id);
      expect(servidor.compras.single['descripcion'], 'Pan');

      await api.descartar(api.pendientes.single.id);
      expect(api.pendientes, isEmpty);
      expect(api.red.conError, 0);
    },
  );

  test(
    'un cambio con red espera a que la cola termine, para conservar el orden',
    () async {
      servidor.sinRed = true;
      await apuntar('Pan');
      servidor
        ..sinRed = false
        ..registro.clear();

      // Algo que llegó con red: primero sale lo de la cola.
      await api.obtener<Object>('/api/salud');
      await api.sincronizar();
      await apuntar('Leche');

      final altas = servidor.registro
          .where((r) => r.startsWith('POST'))
          .toList();
      expect(altas, hasLength(2));
      expect(servidor.compras.map((c) => c['descripcion']), ['Pan', 'Leche']);
    },
  );

  test('sin superposición, un cambio sin red falla como siempre', () async {
    servidor.sinRed = true;
    expect(
      () => api.publicar<Object>('/api/deudas', cuerpo: {'x': 1}),
      throwsA(isA<ErrorApi>().having((e) => e.esDeConexion, 'conexión', true)),
    );
    expect(api.pendientes, isEmpty);
  });

  test('el identificador es un UUID v7', () {
    final id = nuevoIdentificador(ahora: DateTime.utc(2026, 11, 22));
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(id),
      isTrue,
    );
    // Los primeros 48 bits son la marca de tiempo en milisegundos.
    final ms = int.parse(id.replaceAll('-', '').substring(0, 12), radix: 16);
    expect(ms, DateTime.utc(2026, 11, 22).millisecondsSinceEpoch);
  });
}
