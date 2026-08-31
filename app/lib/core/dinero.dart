/// Interpretación de importes escritos por personas o por bancos.
///
/// Vive aparte porque hacen falta en dos sitios que no se parecen en nada: al reconocer una
/// notificación de pago y al teclear una compra a mano. La regla es delicada y tenerla dos
/// veces garantizaría que las dos versiones acabaran discrepando.
library;

class Dinero {
  const Dinero._();

  /// Convierte a número un importe escrito en cualquiera de los dos formatos que se usan.
  ///
  /// Y hacen falta los dos: en Colombia se escribe `192.729,03`, pero el teléfono en inglés
  /// —y Google Wallet con él— escribe `192,729.03`. El punto y la coma significan lo contrario
  /// en cada uno, así que dar por buena una convención convertiría 192.729 pesos en 192,73.
  ///
  /// La regla que los distingue sin ambigüedad: **el último separador es el decimal solo si le
  /// siguen exactamente dos dígitos.** Con tres es separador de miles, porque no existe una
  /// moneda con tres decimales que se escriba así.
  static double? interpretar(String texto) {
    final limpio = texto.replaceAll(RegExp(r'[^\d.,]'), '');
    if (limpio.isEmpty) return null;

    final ultimoPunto = limpio.lastIndexOf('.');
    final ultimaComa = limpio.lastIndexOf(',');
    final ultimoSeparador = ultimoPunto > ultimaComa ? ultimoPunto : ultimaComa;

    String enteroYDecimal;
    if (ultimoSeparador == -1) {
      enteroYDecimal = limpio;
    } else {
      final decimales = limpio.length - ultimoSeparador - 1;
      if (decimales == 2) {
        final entero = limpio
            .substring(0, ultimoSeparador)
            .replaceAll(RegExp(r'[.,]'), '');
        enteroYDecimal = '$entero.${limpio.substring(ultimoSeparador + 1)}';
      } else {
        // Todos los separadores son de miles.
        enteroYDecimal = limpio.replaceAll(RegExp(r'[.,]'), '');
      }
    }

    return double.tryParse(enteroYDecimal);
  }

  /// Cómo se escribe un importe dentro de un campo de texto editable.
  ///
  /// Sin separadores de miles, porque estorban al corregir una cifra, y con la coma decimal
  /// que es la que se teclea en Colombia. Los centavos solo aparecen si los hay.
  static String paraEditar(double valor) {
    final centavos = (valor * 100).round();
    if (centavos % 100 == 0) return (centavos ~/ 100).toString();
    return (centavos / 100).toStringAsFixed(2).replaceAll('.', ',');
  }
}
