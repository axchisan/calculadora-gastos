import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../dominio/captura_pago.dart';

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
