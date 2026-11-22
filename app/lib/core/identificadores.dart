import 'dart:math';

final Random _azar = Random.secure();

/// Identificador UUID v7, el mismo formato que genera el backend.
///
/// La app lo genera al apuntar algo, para poder enviarlo más tarde si no hay conexión: el
/// servidor reconoce el reenvío por este identificador y no lo duplica. Los v7 empiezan por la
/// marca de tiempo, así que ordenan por fecha de creación igual que los del servidor.
String nuevoIdentificador({DateTime? ahora}) {
  final ms = (ahora ?? DateTime.now()).millisecondsSinceEpoch;
  final bytes = List<int>.generate(16, (_) => _azar.nextInt(256));
  for (var i = 0; i < 6; i++) {
    bytes[i] = (ms >> (8 * (5 - i))) & 0xff;
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x70; // versión 7
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
