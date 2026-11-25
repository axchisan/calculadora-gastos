import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// La foto que el usuario elige para una meta («lo que quiero comprar»).
///
/// Se guarda solo en este dispositivo y nunca sube al servidor ni al código: el repositorio es
/// público y la foto suele ser de un producto con derechos de autor. Cada dispositivo puede
/// tener la suya.
class FotoDeMeta {
  const FotoDeMeta();

  /// Más grande que esto no se guarda: SharedPreferences no es para archivos grandes.
  static const int maximoBytes = 3 * 1024 * 1024;

  static String _clave(String metaId) => 'meta.foto.$metaId';

  Future<Uint8List?> leer(String metaId) async {
    final texto = (await SharedPreferences.getInstance()).getString(
      _clave(metaId),
    );
    if (texto == null) return null;
    try {
      return base64Decode(texto);
    } on FormatException {
      return null;
    }
  }

  /// Guarda la foto; false si es demasiado grande.
  Future<bool> guardar(String metaId, Uint8List bytes) async {
    if (bytes.length > maximoBytes) return false;
    await (await SharedPreferences.getInstance()).setString(
      _clave(metaId),
      base64Encode(bytes),
    );
    return true;
  }

  Future<void> quitar(String metaId) async =>
      (await SharedPreferences.getInstance()).remove(_clave(metaId));
}
