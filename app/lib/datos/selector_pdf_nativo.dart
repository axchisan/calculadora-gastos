import 'package:flutter/services.dart';

const MethodChannel _canal = MethodChannel(
  'com.axchisan.calculadora_gastos/extractos',
);

Future<Uint8List?> elegirPdf() async {
  try {
    return await _canal.invokeMethod<Uint8List>('elegirPdf');
  } on MissingPluginException {
    return null;
  }
}

Future<Uint8List?> elegirImagen() async {
  try {
    return await _canal.invokeMethod<Uint8List>('elegirImagen');
  } on MissingPluginException {
    return null;
  }
}
