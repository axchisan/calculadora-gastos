/// Reconocimiento de los pagos a partir de las notificaciones del teléfono.
///
/// Google Wallet no publica ninguna forma de consultar lo que se pagó —la API que existe con
/// ese nombre sirve para emitir pases, no para leerlos— y Android no permite que una aplicación
/// observe lo que hace el servicio de pago. Lo único que queda al alcance son las notificaciones
/// que el propio teléfono ya muestra, y de ahí sale todo esto.
///
/// El reconocimiento vive en Dart y no en Kotlin a propósito: así se puede probar contra los
/// textos reales sin arrancar un teléfono. La parte nativa se limita a capturar la notificación
/// tal cual llega.
library;

/// Una notificación tal y como la capturó Android, sin interpretar.
class NotificacionCapturada {
  const NotificacionCapturada({
    required this.id,
    required this.paquete,
    required this.titulo,
    required this.texto,
    required this.instante,
  });

  final String id;

  /// Paquete de la aplicación que la publicó.
  final String paquete;

  final String titulo;
  final String texto;
  final DateTime instante;

  static NotificacionCapturada deJson(Map<String, dynamic> j) =>
      NotificacionCapturada(
        id: j['id'] as String,
        paquete: j['paquete'] as String? ?? '',
        titulo: j['titulo'] as String? ?? '',
        texto: j['texto'] as String? ?? '',
        instante: DateTime.fromMillisecondsSinceEpoch(
          (j['instante'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// De dónde salió el reconocimiento.
enum FuenteCaptura {
  /// Llega en toda compra hecha acercando el teléfono, sea la tarjeta que sea.
  wallet('Google Wallet'),

  /// Llega también cuando se usa la tarjeta física, y es la única que da los cuatro dígitos.
  banco('Notificación del banco');

  const FuenteCaptura(this.etiqueta);

  final String etiqueta;
}

/// Un pago reconocido dentro de una notificación.
class PagoDetectado {
  const PagoDetectado({
    required this.monto,
    required this.instante,
    required this.fuente,
    required this.textoOriginal,
    this.comercio,
    this.apodoTarjeta,
    this.ultimos4,
  });

  final double monto;
  final DateTime instante;
  final FuenteCaptura fuente;

  /// El texto de la notificación, guardado para poder revisar un reconocimiento dudoso.
  final String textoOriginal;

  final String? comercio;

  /// El nombre que la tarjeta tiene dentro de Google Wallet: «crédito física».
  final String? apodoTarjeta;

  /// Los cuatro últimos dígitos, que solo publica el banco.
  final String? ultimos4;

  /// Dos notificaciones del mismo importe tan seguidas son la misma compra.
  ///
  /// Al pagar llegan dos: la de la billetera y la del banco. Sin esto, cada compra entraría
  /// por duplicado.
  static const Duration ventanaDeDuplicado = Duration(minutes: 5);

  bool esLaMismaCompraQue(PagoDetectado otro) {
    if (monto != otro.monto) return false;
    return instante.difference(otro.instante).abs() <= ventanaDeDuplicado;
  }

  /// Junta lo que aporta cada notificación de la misma compra.
  ///
  /// La billetera trae el comercio limpio en el título y el apodo de la tarjeta; el banco trae
  /// los cuatro dígitos, que es el dato que identifica la tarjeta sin ambigüedad. Quedarse solo
  /// con una de las dos desaprovecharía la mitad de la información.
  PagoDetectado fusionarCon(PagoDetectado otro) {
    return PagoDetectado(
      monto: monto,
      // El instante más temprano: es el momento real de la compra.
      instante: instante.isBefore(otro.instante) ? instante : otro.instante,
      fuente: fuente,
      textoOriginal: textoOriginal,
      comercio: comercio ?? otro.comercio,
      apodoTarjeta: apodoTarjeta ?? otro.apodoTarjeta,
      ultimos4: ultimos4 ?? otro.ultimos4,
    );
  }
}

/// Interpreta las notificaciones de pago.
class LectorDePagos {
  const LectorDePagos._();

  /// Paquetes cuyas notificaciones interesa mirar.
  ///
  /// Se filtra en la parte nativa para no traer a Dart todas las notificaciones del teléfono,
  /// que serían cientos al día y ninguna relacionada con dinero.
  static const List<String> paquetesVigilados = [
    'com.google.android.apps.walletnfcrel',
    'com.nu.production',
  ];

  /// Reconoce un pago dentro de una notificación, o devuelve null si no lo es.
  static PagoDetectado? leer(NotificacionCapturada notificacion) {
    if (notificacion.paquete.contains('walletnfcrel')) {
      return _leerWallet(notificacion);
    }
    if (notificacion.paquete.contains('nu.production')) {
      return _leerNu(notificacion);
    }
    return null;
  }

  /// Google Wallet: el comercio va en el título y el resto en el texto.
  ///
  /// ```
  /// título:  SURTIMAYORISTA CLARET
  /// texto:   COP54,670.00 with crédito física
  /// ```
  ///
  /// El «with» aparece en inglés porque así está el sistema del teléfono; se admite también
  /// «con» por si algún día cambia el idioma.
  static PagoDetectado? _leerWallet(NotificacionCapturada n) {
    final coincidencia = _patronWallet.firstMatch(n.texto);
    if (coincidencia == null) return null;

    final monto = interpretarMonto(coincidencia.group(1)!);
    if (monto == null || monto <= 0) return null;

    final apodo = coincidencia.group(2)?.trim();

    return PagoDetectado(
      monto: monto,
      instante: n.instante,
      fuente: FuenteCaptura.wallet,
      textoOriginal: '${n.titulo} · ${n.texto}',
      comercio: n.titulo.trim().isEmpty ? null : n.titulo.trim(),
      apodoTarjeta: apodo == null || apodo.isEmpty ? null : apodo,
    );
  }

  /// Nu: el importe va en el título y el detalle en el texto.
  ///
  /// ```
  /// título:  Compra aprobada por $54.670,00
  /// texto:   Tu compra en SURTIMAYORISTA CLARET por $54.670,00 con tu tarjeta
  ///          terminada en 2355 ha sido APROBADA.
  /// ```
  ///
  /// Solo se reconocen las aprobadas. Una compra rechazada no movió dinero, y capturarla
  /// llenaría la bandeja de cosas que hay que descartar a mano.
  static PagoDetectado? _leerNu(NotificacionCapturada n) {
    final todo = '${n.titulo} ${n.texto}';
    if (!todo.toLowerCase().contains('aprobad')) return null;

    final coincidencia = _patronNu.firstMatch(n.texto);
    final montoTexto =
        coincidencia?.group(2) ??
        _patronMontoSuelto.firstMatch(n.titulo)?.group(1);
    if (montoTexto == null) return null;

    final monto = interpretarMonto(montoTexto);
    if (monto == null || monto <= 0) return null;

    return PagoDetectado(
      monto: monto,
      instante: n.instante,
      fuente: FuenteCaptura.banco,
      textoOriginal: '${n.titulo} · ${n.texto}',
      comercio: coincidencia?.group(1)?.trim(),
      ultimos4: coincidencia?.group(3),
    );
  }

  /// `COP54,670.00 with crédito física`
  static final RegExp _patronWallet = RegExp(
    r'^\s*(?:COP\s*)?\$?\s*([\d.,]+)\s+(?:with|con)\s+(.+?)\s*$',
    caseSensitive: false,
  );

  /// `Tu compra en COMERCIO por $54.670,00 con tu tarjeta terminada en 2355`
  static final RegExp _patronNu = RegExp(
    r'compra en\s+(.+?)\s+por\s+\$?\s*([\d.,]+).*?terminada en\s+(\d{4})',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _patronMontoSuelto = RegExp(r'\$\s*([\d.,]+)');

  /// Convierte a número un importe escrito en cualquiera de los dos formatos que llegan.
  ///
  /// Y llegan los dos, en la misma compra: Google Wallet lo escribe a la americana
  /// (`54,670.00`) porque el sistema del teléfono está en inglés, y el banco a la colombiana
  /// (`54.670,00`). El punto y la coma significan lo contrario en cada uno, así que dar por
  /// buena una de las dos convenciones convertiría 54.670 pesos en 54,67.
  ///
  /// La regla que los distingue sin ambigüedad: **el último separador es el decimal solo si le
  /// siguen exactamente dos dígitos.** Con tres es un separador de miles, porque no existe una
  /// moneda con tres decimales que se escriba así.
  static double? interpretarMonto(String texto) {
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
}
