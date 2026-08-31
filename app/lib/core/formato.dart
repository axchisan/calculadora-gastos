import 'package:intl/intl.dart';

/// Formato de dinero y fechas en español de Colombia.
///
/// El peso colombiano no usa decimales en el día a día, así que se muestran cifras enteras con
/// punto como separador de miles: `$3.174.000`.
class Formato {
  const Formato._();

  static const String _localeCo = 'es_CO';

  /// El patrón se fija a mano porque la definición estándar de `es_CO` coloca el símbolo
  /// detrás de la cifra (`3.174.000 $`), mientras que en Colombia se escribe delante y sin
  /// espacio: `$3.174.000`. El carácter `¤` es el marcador del símbolo de moneda.
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: _localeCo,
    symbol: r'$',
    decimalDigits: 0,
    customPattern: '¤#,##0',
  );

  /// El mismo formato con los centavos: `$192.729,03`.
  static final NumberFormat _monedaConCentavos = NumberFormat.currency(
    locale: _localeCo,
    symbol: r'$',
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );

  static final NumberFormat _compacto = NumberFormat.compact(locale: _localeCo);

  static final NumberFormat _numero = NumberFormat.decimalPattern(_localeCo);

  static final DateFormat _fechaLarga = DateFormat(
    "d 'de' MMMM 'de' y",
    _localeCo,
  );
  static final DateFormat _fechaCorta = DateFormat('d MMM', _localeCo);
  static final DateFormat _mesYAnio = DateFormat('MMMM y', _localeCo);
  static final DateFormat _diaSemana = DateFormat('EEEE', _localeCo);
  static final DateFormat _hora = DateFormat('HH:mm', _localeCo);

  /// `$3.174.000`, o `$192.729,03` si la cifra tiene centavos.
  ///
  /// Los centavos solo aparecen cuando existen. En el día a día el peso colombiano se maneja en
  /// cifras redondas y arrastrar «,00» detrás de cada importe emborrona la lectura; pero un
  /// plan de pagos o un extracto sí traen decimales, y redondearlos descuadraría las cuentas
  /// contra el papel del banco.
  static String dinero(num valor) => tieneCentavos(valor)
      ? _monedaConCentavos.format(valor)
      : _moneda.format(valor);

  /// Fuerza los centavos aunque sean cero. Para columnas donde deben cuadrar verticalmente.
  static String dineroExacto(num valor) => _monedaConCentavos.format(valor);

  /// Si la cifra tiene centavos que se perderían al redondear.
  ///
  /// Se compara sobre céntimos enteros y no con `valor != valor.round()` porque en coma
  /// flotante 192729.03 no es exactamente eso, y la comparación directa daría verdadero para
  /// cifras que en realidad son redondas.
  static bool tieneCentavos(num valor) => (valor * 100).round() % 100 != 0;

  /// `$3,2 M` — para ejes de gráficas, donde no cabe la cifra completa.
  static String dineroCompacto(num valor) => '\$${_compacto.format(valor)}';

  /// Igual que [dinero] pero anteponiendo el signo en los valores positivos, para mostrar
  /// variaciones donde importa distinguir si se sumó o se restó.
  static String dineroConSigno(num valor) =>
      valor > 0 ? '+${dinero(valor)}' : dinero(valor);

  /// `1.234`
  static String numero(num valor) => _numero.format(valor);

  /// `53,4%`
  static String porcentaje(num valor) =>
      '${_numero.format(valor.toDouble().roundToDouble() == valor ? valor : double.parse(valor.toStringAsFixed(1)))}%';

  /// `10:16 del 21 ago`
  static String horaYFecha(DateTime valor) =>
      '${_hora.format(valor)} del ${fechaCorta(valor)}';

  /// `17 de agosto de 2026`
  static String fecha(DateTime valor) => _fechaLarga.format(valor);

  /// `17 ago`
  static String fechaCorta(DateTime valor) => _fechaCorta.format(valor);

  /// `agosto 2026`, con la inicial en mayúscula.
  static String mesYAnio(DateTime valor) =>
      _capitalizar(_mesYAnio.format(valor));

  /// `lunes`, con la inicial en mayúscula.
  static String diaDeLaSemana(DateTime valor) =>
      _capitalizar(_diaSemana.format(valor));

  /// Nombre del mes a partir de su número, de 1 a 12.
  static String nombreDeMes(int mes) =>
      _capitalizar(DateFormat('MMMM', _localeCo).format(DateTime(2026, mes)));

  static String _capitalizar(String texto) =>
      texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
}
