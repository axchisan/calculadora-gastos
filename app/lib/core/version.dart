import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Datos de la compilación que se está ejecutando.
///
/// Se leen del paquete instalado y no de una constante escrita a mano: el número vive en
/// `pubspec.yaml`, y duplicarlo en el código garantizaba que antes o después se quedara viejo.
class VersionApp {
  const VersionApp({
    required this.nombre,
    required this.version,
    required this.compilacion,
  });

  /// Nombre con el que la aplicación aparece en el sistema.
  final String nombre;

  /// Versión visible, del estilo `1.6.0`.
  final String version;

  /// Número de compilación, el que sube en cada publicación de Android.
  final String compilacion;

  /// Plataforma en la que se está ejecutando, en palabras.
  static String get plataforma {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }
}

final versionProvider = FutureProvider<VersionApp>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return VersionApp(
    nombre: info.appName,
    version: info.version,
    compilacion: info.buildNumber,
  );
});
