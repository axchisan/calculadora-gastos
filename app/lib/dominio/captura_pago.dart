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

import '../core/dinero.dart';

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
  banco('Notificación del banco'),

  /// El SMS del banco. Llega en compras donde no interviene el teléfono —una máquina
  /// expendedora, una compra por internet— y es el más completo de los tres.
  sms('SMS del banco');

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
    this.esCredito,
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

  /// Si el aviso decía que la tarjeta era de crédito o de débito.
  ///
  /// Solo lo dice el SMS del banco, con «T.Deb» o «T.Cred». Sirve de red: si la tarjeta no
  /// está configurada todavía, al menos se sabe si el dinero sale hoy o en el corte.
  final bool? esCredito;

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
      esCredito: esCredito ?? otro.esCredito,
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
    // Los SMS del banco los muestra la aplicación de mensajes, no el banco.
    'com.google.android.apps.messaging',
  ];

  /// Reconoce un pago dentro de una notificación, o devuelve null si no lo es.
  static PagoDetectado? leer(NotificacionCapturada notificacion) {
    if (notificacion.paquete.contains('walletnfcrel')) {
      return _leerWallet(notificacion);
    }
    if (notificacion.paquete.contains('nu.production')) {
      return _leerNu(notificacion);
    }
    if (notificacion.paquete.contains('messaging')) {
      return _leerSmsDeBancolombia(notificacion);
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

  /// El SMS de Bancolombia, que la aplicación de mensajes muestra como notificación.
  ///
  /// ```
  /// título:  85784
  /// texto:   Bancolombia: Compraste $9.000,00 en NOVAVENTA BOG CODIGO con tu
  ///          T.Deb *8329, el 18/08/2026 a las 10:08. Si tienes dudas...
  /// ```
  ///
  /// Es el aviso más completo de los tres: trae el importe, el comercio, los cuatro dígitos,
  /// **si la tarjeta es de débito o de crédito** y la hora real de la compra. Y llega en los
  /// casos donde el teléfono no interviene —una máquina expendedora, una compra por internet—,
  /// que es justo donde no hay notificación de la billetera.
  static PagoDetectado? _leerSmsDeBancolombia(NotificacionCapturada n) {
    final coincidencia = _patronBancolombia.firstMatch(n.texto);
    if (coincidencia == null) return null;

    final monto = interpretarMonto(coincidencia.group(1)!);
    if (monto == null || monto <= 0) return null;

    // «T.Deb» o «T.Cred». Se mira solo el principio porque el banco no siempre escribe la
    // palabra entera.
    final tipo = coincidencia.group(3)!.toLowerCase();
    final esCredito = tipo.contains('cred');

    return PagoDetectado(
      monto: monto,
      // La hora que trae el mensaje gana a la de llegada: un SMS puede tardar minutos, y con
      // una compra a crédito hecha el día del corte esos minutos deciden el mes de pago.
      instante: _fechaDelSms(n.texto) ?? n.instante,
      fuente: FuenteCaptura.sms,
      textoOriginal: n.texto,
      comercio: coincidencia.group(2)?.trim(),
      ultimos4: coincidencia.group(4),
      esCredito: esCredito,
    );
  }

  /// La fecha y la hora que el propio mensaje declara: `el 18/08/2026 a las 10:08`.
  static DateTime? _fechaDelSms(String texto) {
    final coincidencia = _patronFechaSms.firstMatch(texto);
    if (coincidencia == null) return null;

    return DateTime(
      int.parse(coincidencia.group(3)!),
      int.parse(coincidencia.group(2)!),
      int.parse(coincidencia.group(1)!),
      int.parse(coincidencia.group(4)!),
      int.parse(coincidencia.group(5)!),
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

  /// `Compraste $9.000,00 en NOVAVENTA BOG CODIGO con tu T.Deb *8329`
  static final RegExp _patronBancolombia = RegExp(
    r'compraste\s+\$?\s*([\d.,]+)\s+en\s+(.+?)\s+con\s+tu\s+'
    r'(T\.?\s*(?:Deb|Cred)\w*)\s*\*?\s*(\d{4})',
    caseSensitive: false,
    dotAll: true,
  );

  /// `el 18/08/2026 a las 10:08`
  static final RegExp _patronFechaSms = RegExp(
    r'el\s+(\d{1,2})/(\d{1,2})/(\d{4})\s+a\s+las\s+(\d{1,2}):(\d{2})',
    caseSensitive: false,
  );

  /// Convierte a número un importe escrito en cualquiera de los dos formatos que llegan.
  ///
  /// Delega en [Dinero.interpretar], que es la misma regla que se aplica al teclear una compra
  /// a mano: si el reconocimiento y el teclado interpretaran distinto un mismo importe, la
  /// aplicación se contradiría a sí misma.
  static double? interpretarMonto(String texto) => Dinero.interpretar(texto);
}
