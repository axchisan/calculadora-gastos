import 'package:calculadora_gastos/datos/script_gmail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el script lleva la dirección de la API y la clave, sin marcadores', () {
    final s = scriptGmail(urlApi: 'https://api.ejemplo.co', clave: 'gk_prueba');
    expect(s, contains("const API = 'https://api.ejemplo.co';"));
    expect(s, contains("const CLAVE = 'gk_prueba';"));
    expect(s, isNot(contains('{{')));
    expect(s, contains('function instalar()'));
    expect(s, contains("'X-Clave-Ingesta': CLAVE"));
    // Solo correos firmados por el banco, y solo la frase del aviso.
    expect(s, contains('dkim=pass'));
    expect(s, contains("origen: 'CORREO'"));
  });
}
