/// Interpretación de importes escritos por personas o por bancos.
///
/// Vive aparte porque hacen falta en dos sitios que no se parecen en nada: al reconocer una
/// notificación de pago y al teclear una compra a mano. La regla es delicada y tenerla dos
/// veces garantizaría que las dos versiones acabaran discrepando.
library;

import 'package:flutter/services.dart';

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

  /// Convierte a número una tasa o un porcentaje, donde el separador siempre es decimal.
  ///
  /// Aquí no sirve [interpretar]: su regla de los dos decimales está pensada para importes, y
  /// con ella un interés del `2,5` acabaría siendo del 25 %, porque en un importe una sola cifra
  /// detrás del separador solo puede ser un separador de miles. En una tasa no hay miles que
  /// separar, así que la lectura no tiene ambigüedad y el punto y la coma valen lo mismo.
  static double? interpretarTasa(String texto) {
    final limpio = texto
        .replaceAll(RegExp(r'[^\d.,]'), '')
        .replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    return double.tryParse(limpio);
  }

  /// Cómo se escribe un importe dentro de un campo de texto editable.
  ///
  /// Con los separadores de miles puestos, igual que quedaría al teclearlo: un campo que se
  /// abre con `192729` y pasa a `192.729` en cuanto se toca una tecla desconcierta. Los
  /// centavos solo aparecen si los hay.
  static String paraEditar(double valor) {
    final centavos = (valor * 100).round();
    final entero = FormatoDeImporte.conSeparadores('${centavos ~/ 100}');

    if (centavos % 100 == 0) return entero;
    return '$entero,${(centavos % 100).toString().padLeft(2, '0')}';
  }
}

/// Va poniendo los puntos de miles mientras se teclea un importe.
///
/// Sin esto, escribir 192729 obliga a contar las cifras a ojo para saber si son ciento noventa
/// mil o un millón novecientos. Con el separador puesto sobre la marcha, el error de un cero de
/// más se ve en el momento en lugar de descubrirse al revisar las cuentas.
class FormatoDeImporte extends TextInputFormatter {
  const FormatoDeImporte() : separadorDeMiles = true, decimalesMaximos = 2;

  /// Para tasas y porcentajes, que se teclean con coma decimal pero nunca llegan a mil y no
  /// llevan separador de miles. Lo que se escriba con ellos se lee con [Dinero.interpretarTasa].
  ///
  /// Admiten cuatro decimales porque así se guarda el interés de una deuda; los porcentajes que
  /// se almacenan con dos pasan ese límite al crearlos, para no prometer una precisión que la
  /// base de datos va a redondear sin avisar.
  const FormatoDeImporte.tasa({this.decimalesMaximos = 4})
    : separadorDeMiles = false;

  final bool separadorDeMiles;

  /// Cuántas cifras se admiten detrás de la coma.
  final int decimalesMaximos;

  /// El separador decimal que se teclea en Colombia.
  static const String _coma = ',';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    // Se admite un único separador decimal, y solo dos cifras detrás: no existe medio centavo.
    final limpio = nuevo.text.replaceAll(RegExp(r'[^\d,.]'), '');
    final unificado = limpio.replaceAll('.', _coma);

    final partes = unificado.split(_coma);
    final entero = partes.first.replaceAll(RegExp(r'\D'), '');
    final decimales = partes.length > 1
        ? partes[1].replaceAll(RegExp(r'\D'), '')
        : null;

    if (entero.isEmpty && decimales == null) {
      return const TextEditingValue();
    }

    final buffer = StringBuffer(
      separadorDeMiles ? conSeparadores(entero) : entero,
    );
    if (decimales != null) {
      // Se conserva la coma aunque todavía no haya cifras detrás: quien acaba de teclearla
      // está a mitad de escribir los centavos, y borrársela sería pelearse con el usuario.
      buffer
        ..write(_coma)
        ..write(
          decimales.length > decimalesMaximos
              ? decimales.substring(0, decimalesMaximos)
              : decimales,
        );
    }

    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      // El cursor se deja al final. Mantener su posición exacta al reescribir el texto es
      // frágil y aquí no aporta: se escribe de izquierda a derecha y se corrige borrando.
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  /// `192729` → `192.729`
  static String conSeparadores(String digitos) {
    if (digitos.length <= 3) return digitos;

    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      // Un punto cada tres cifras contando desde la derecha.
      if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digitos[i]);
    }
    return buffer.toString();
  }
}
