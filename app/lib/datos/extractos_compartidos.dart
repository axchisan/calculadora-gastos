import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// El extracto en PDF que llega con «Compartir» o «Abrir con» desde otra aplicación de
/// Android (WhatsApp, Gmail, Archivos).
class ExtractosCompartidos {
  const ExtractosCompartidos();

  static const MethodChannel _canal = MethodChannel(
    'com.axchisan.calculadora_gastos/extractos',
  );

  bool get disponible => !kIsWeb && Platform.isAndroid;

  /// El PDF que espera, si hay uno. Solo se entrega una vez.
  Future<Uint8List?> tomar() async {
    if (!disponible) return null;
    try {
      return await _canal.invokeMethod<Uint8List>('tomarPdf');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Con la aplicación abierta, avisa cuando se comparte otro PDF.
  void alRecibir(VoidCallback accion) {
    if (!disponible) return;
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'pdfRecibido') accion();
    });
  }
}
