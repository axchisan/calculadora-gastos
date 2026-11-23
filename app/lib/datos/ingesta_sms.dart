import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cómo está la lectura de los SMS del banco en este teléfono.
class EstadoSms {
  const EstadoSms({
    required this.permiso,
    required this.activo,
    required this.pendientes,
    this.ultimoEnvio,
  });

  final bool permiso;

  /// Si el teléfono tiene una clave y reenvía los SMS al llegar.
  final bool activo;

  /// SMS que esperan conexión para enviarse.
  final int pendientes;
  final DateTime? ultimoEnvio;
}

/// Un SMS del banco guardado en el teléfono.
class SmsDelBanco {
  const SmsDelBanco(this.texto, this.fecha);

  final String texto;
  final DateTime fecha;
}

/// Puente con el receptor de SMS de Android (ReceptorSms y EnvioDeAvisos).
class IngestaSms {
  const IngestaSms();

  static const MethodChannel _canal = MethodChannel(
    'com.axchisan.calculadora_gastos/sms',
  );

  bool get disponible => !kIsWeb && Platform.isAndroid;

  Future<EstadoSms?> estado() async {
    if (!disponible) return null;
    final m = await _canal.invokeMapMethod<String, dynamic>('estado');
    if (m == null) return null;
    final ultimo = (m['ultimoEnvio'] as num?)?.toInt() ?? 0;
    return EstadoSms(
      permiso: m['permiso'] as bool? ?? false,
      activo: m['activo'] as bool? ?? false,
      pendientes: (m['pendientes'] as num?)?.toInt() ?? 0,
      ultimoEnvio: ultimo > 0
          ? DateTime.fromMillisecondsSinceEpoch(ultimo)
          : null,
    );
  }

  Future<bool> pedirPermiso() async =>
      await _canal.invokeMethod<bool>('pedirPermiso') ?? false;

  /// Deja al teléfono reenviando los SMS del banco con esa clave; null lo apaga.
  Future<void> configurar({String? url, String? clave}) =>
      _canal.invokeMethod<void>('configurar', {'url': url, 'clave': clave});

  /// Los SMS del banco guardados desde [desde], del más viejo al más reciente.
  Future<List<SmsDelBanco>> historial(DateTime desde) async {
    final lista = await _canal.invokeListMethod<dynamic>('historial', {
      'desde': desde.millisecondsSinceEpoch,
    });
    return [
      for (final e in lista ?? const [])
        SmsDelBanco(
          (e as Map)['texto'] as String,
          DateTime.fromMillisecondsSinceEpoch((e['fecha'] as num).toInt()),
        ),
    ];
  }
}
