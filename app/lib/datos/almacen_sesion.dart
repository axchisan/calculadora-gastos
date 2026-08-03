import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sesión guardada en el dispositivo.
class SesionGuardada {
  const SesionGuardada({
    required this.accessToken,
    required this.refreshToken,
    required this.expiraEn,
    required this.usuarioId,
    required this.email,
    required this.nombre,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiraEn;
  final String usuarioId;
  final String email;
  final String nombre;

  bool get estaVigente => DateTime.now().isBefore(expiraEn);

  Map<String, dynamic> aJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiraEn': expiraEn.toIso8601String(),
    'usuarioId': usuarioId,
    'email': email,
    'nombre': nombre,
  };

  static SesionGuardada deJson(Map<String, dynamic> json) => SesionGuardada(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiraEn: DateTime.parse(json['expiraEn'] as String),
    usuarioId: json['usuarioId'] as String,
    email: json['email'] as String,
    nombre: json['nombre'] as String,
  );

  /// Construye la sesión a partir de la respuesta de la API.
  static SesionGuardada deRespuesta(Map<String, dynamic> respuesta) {
    final usuario = respuesta['usuario'] as Map<String, dynamic>;
    return SesionGuardada(
      accessToken: respuesta['accessToken'] as String,
      refreshToken: respuesta['refreshToken'] as String,
      expiraEn: DateTime.now().add(
        Duration(seconds: respuesta['expiraEn'] as int),
      ),
      usuarioId: usuario['id'] as String,
      email: usuario['email'] as String,
      nombre: usuario['nombre'] as String,
    );
  }

  SesionGuardada copiarCon({
    String? accessToken,
    String? refreshToken,
    DateTime? expiraEn,
  }) => SesionGuardada(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiraEn: expiraEn ?? this.expiraEn,
    usuarioId: usuarioId,
    email: email,
    nombre: nombre,
  );
}

/// Guarda la sesión en el almacén seguro de cada plataforma.
///
/// En macOS usa el Keychain y en Android el Keystore. En web no existe un equivalente, así que
/// el paquete recurre a `localStorage`: es la razón por la que el token de acceso dura solo
/// quince minutos.
class AlmacenSesion {
  AlmacenSesion({FlutterSecureStorage? almacen})
    : _almacen =
          almacen ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const String _clave = 'sesion';

  final FlutterSecureStorage _almacen;

  Future<SesionGuardada?> leer() async {
    final crudo = await _almacen.read(key: _clave);
    if (crudo == null) return null;
    try {
      return SesionGuardada.deJson(jsonDecode(crudo) as Map<String, dynamic>);
    } on FormatException {
      // Un formato ilegible solo puede venir de una versión anterior de la app; se descarta
      // para que el usuario vuelva a entrar en lugar de quedarse en un error permanente.
      await borrar();
      return null;
    }
  }

  Future<void> guardar(SesionGuardada sesion) =>
      _almacen.write(key: _clave, value: jsonEncode(sesion.aJson()));

  Future<void> borrar() => _almacen.delete(key: _clave);
}
