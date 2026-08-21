import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../dominio/captura_pago.dart';

/// Cómo está la captura de pagos, con el detalle suficiente para saber qué falta.
///
/// Android enseña todo esto como un único interruptor, pero son cosas distintas: se puede tener
/// el permiso concedido y el servicio sin enganchar, y en ese estado no llega ni una captura
/// sin que nada lo advierta.
class EstadoCaptura {
  const EstadoCaptura({
    required this.permiso,
    required this.avisosPermitidos,
    required this.bateriaLibre,
    required this.capturas,
    this.conectadoDesde,
  });

  /// El acceso a notificaciones está concedido.
  final bool permiso;

  /// La aplicación puede publicar sus propios avisos.
  final bool avisosPermitidos;

  /// El sistema no restringe a la aplicación en segundo plano.
  final bool bateriaLibre;

  /// Cuántas capturas hay guardadas sin resolver.
  final int capturas;

  /// Desde cuándo el servicio está enganchado, o nulo si no lo está.
  final DateTime? conectadoDesde;

  /// Si el servicio está de verdad recibiendo notificaciones.
  bool get enganchado => conectadoDesde != null;

  /// Si todo lo necesario está en su sitio.
  bool get todoListo => permiso && enganchado && avisosPermitidos;

  static EstadoCaptura deJson(Map<String, Object?> j) => EstadoCaptura(
    permiso: j['permiso'] as bool? ?? false,
    avisosPermitidos: j['avisosPermitidos'] as bool? ?? false,
    bateriaLibre: j['bateriaLibre'] as bool? ?? false,
    capturas: (j['capturas'] as num?)?.toInt() ?? 0,
    conectadoDesde: j['conectadoDesde'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (j['conectadoDesde'] as num).toInt(),
          ),
  );
}

/// Acceso a las notificaciones de pago que recoge el servicio de Android.
///
/// Solo hace algo en Android. En la web y en macOS no existe nada equivalente —ni Apple ni los
/// navegadores dejan leer las notificaciones de otras aplicaciones—, así que ahí el registro
/// sigue siendo a mano.
class CapturasAndroid {
  const CapturasAndroid();

  static const MethodChannel _canal = MethodChannel(
    'com.axchisan.calculadora_gastos/capturas',
  );

  /// Indica si la plataforma admite capturar pagos.
  bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Comprueba si el usuario concedió el acceso a las notificaciones.
  Future<bool> permisoConcedido() async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('permisoConcedido') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Lleva a la pantalla de Ajustes donde se concede el permiso.
  ///
  /// No se puede pedir con un diálogo como el resto: es un acceso amplio y Android obliga a
  /// concederlo a mano.
  Future<void> abrirAjustes() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<void>('abrirAjustes');
    } on PlatformException {
      // Si el fabricante no expone esa pantalla, no hay nada que hacer desde aquí.
    }
  }

  /// Indica si la aplicación se instaló desde un APK suelto y no desde una tienda.
  ///
  /// Es lo que decide si hará falta el rodeo por «Permitir ajustes restringidos»: Android 13
  /// bloquea el acceso a notificaciones en las instalaciones laterales y deja el interruptor
  /// apagado sin decir por qué.
  Future<bool> instalacionLateral() async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('instalacionLateral') ?? false;
    } on PlatformException {
      // Ante la duda se asume que sí: enseñar el paso de más no rompe nada, y ocultarlo
      // dejaría al usuario sin saber qué hacer.
      return true;
    }
  }

  /// Abre la ficha de la aplicación en Ajustes, donde vive «Permitir ajustes restringidos».
  Future<void> abrirInfoDeLaApp() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<void>('abrirInfoDeLaApp');
    } on PlatformException {
      // Si el fabricante no expone esa pantalla, no hay nada que hacer desde aquí.
    }
  }

  /// Pide el permiso de publicar avisos, obligatorio desde Android 13.
  Future<void> pedirPermisoDeAvisos() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<void>('pedirPermisoDeAvisos');
    } on PlatformException {
      // En versiones anteriores no hay nada que pedir.
    }
  }

  /// Indica si la aplicación se acaba de abrir tocando el aviso de una compra detectada.
  ///
  /// La respuesta se consume: preguntar dos veces devuelve falso la segunda. Así la aplicación
  /// salta a la bandeja una sola vez y no en cada recarga de la pantalla.
  Future<bool> abiertaDesdeElAviso() async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('abriDesdeElAviso') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Cómo está de verdad la captura de pagos.
  ///
  /// Devuelve nulo fuera de Android.
  Future<EstadoCaptura?> estado() async {
    if (!disponible) return null;
    try {
      final crudo = await _canal.invokeMapMethod<String, Object?>('estado');
      return crudo == null ? null : EstadoCaptura.deJson(crudo);
    } on PlatformException {
      return null;
    }
  }

  /// Pide a Android que vuelva a enganchar el servicio si lo tiene suelto.
  Future<void> reconectar() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<void>('reconectar');
    } on PlatformException {
      // Nada que hacer; el estado seguirá mostrando que no está conectado.
    }
  }

  /// Publica un aviso de prueba por el mismo camino que los de verdad.
  Future<void> probarAviso() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<void>('probarAviso');
    } on PlatformException {
      // Sin permiso de avisos no llegará nada, que es justo lo que la prueba revela.
    }
  }

  Future<void> abrirAjustesDeBateria() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<void>('abrirAjustesDeBateria');
    } on PlatformException {
      // Algunos fabricantes no exponen esa pantalla.
    }
  }

  /// Las notificaciones capturadas que aún no se han resuelto.
  Future<List<NotificacionCapturada>> pendientes() async {
    if (!disponible) return const [];
    try {
      final crudas = await _canal.invokeListMethod<Map<Object?, Object?>>(
        'capturas',
      );
      if (crudas == null) return const [];

      return crudas
          .map((c) => NotificacionCapturada.deJson(c.cast<String, dynamic>()))
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  /// Quita de la lista las capturas ya resueltas, se hayan registrado o descartado.
  Future<void> descartar(List<String> ids) async {
    if (!disponible || ids.isEmpty) return;
    try {
      await _canal.invokeMethod<void>('descartar', ids);
    } on PlatformException {
      // Que no se borre no rompe nada: la captura volvería a aparecer en la bandeja.
    }
  }
}
