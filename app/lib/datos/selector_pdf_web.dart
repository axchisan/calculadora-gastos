import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List?> elegirPdf() {
  final listo = Completer<Uint8List?>();
  final campo = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'application/pdf,.pdf';
  void terminar(Uint8List? bytes) {
    if (!listo.isCompleted) listo.complete(bytes);
  }

  campo.onchange = (web.Event _) {
    final archivo = campo.files?.item(0);
    if (archivo == null) return terminar(null);
    final lector = web.FileReader();
    lector.onload = (web.Event _) {
      final resultado = lector.result;
      terminar(
        resultado.isA<JSArrayBuffer>()
            ? (resultado as JSArrayBuffer).toDart.asUint8List()
            : null,
      );
    }.toJS;
    lector.onerror = (web.Event _) {
      terminar(null);
    }.toJS;
    lector.readAsArrayBuffer(archivo);
  }.toJS;
  campo.addEventListener(
    'cancel',
    (web.Event _) {
      terminar(null);
    }.toJS,
  );
  campo.click();
  return listo.future;
}
