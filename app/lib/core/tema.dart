import 'package:flutter/material.dart';

/// Tema visual de la aplicación.
///
/// Los colores del dinero no son decorativos: en una aplicación de finanzas, distinguir de un
/// vistazo lo pagado de lo pendiente y el saldo positivo del negativo es la función principal
/// de la pantalla.
class Tema {
  const Tema._();

  static const Color _semilla = Color(0xFF00695C);

  /// Verde: dinero disponible, gastos ya pagados, metas cumplidas.
  static const Color positivo = Color(0xFF2E7D32);

  /// Ámbar: pendiente de pagar. No es un error, pero exige atención.
  static const Color pendiente = Color(0xFFEF6C00);

  /// Rojo: saldo negativo, deudas, retiros del ahorro.
  static const Color negativo = Color(0xFFC62828);

  /// Azul: información neutra, como los días de trabajo remoto.
  static const Color neutro = Color(0xFF1565C0);

  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esquema = ColorScheme.fromSeed(
      seedColor: _semilla,
      brightness: brillo,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: esquema.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: esquema.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: esquema.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esquema.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  /// Color que corresponde a un saldo: verde si queda dinero, rojo si falta.
  static Color paraSaldo(num valor) => valor >= 0 ? positivo : negativo;
}

/// Puntos de corte para adaptar la interfaz.
///
/// La aplicación se usa sobre todo en el móvil para consultas rápidas, y en pantalla grande
/// para la planificación del mes, que agradece ver varias cosas a la vez.
class Pantalla {
  const Pantalla._();

  static const double _compacta = 600;
  static const double _media = 1000;

  static bool esMovil(BuildContext contexto) =>
      MediaQuery.sizeOf(contexto).width < _compacta;

  static bool esTablet(BuildContext contexto) {
    final ancho = MediaQuery.sizeOf(contexto).width;
    return ancho >= _compacta && ancho < _media;
  }

  static bool esEscritorio(BuildContext contexto) =>
      MediaQuery.sizeOf(contexto).width >= _media;

  /// Número de columnas para las rejillas de tarjetas.
  static int columnas(BuildContext contexto) {
    final ancho = MediaQuery.sizeOf(contexto).width;
    if (ancho >= _media) return 3;
    if (ancho >= _compacta) return 2;
    return 1;
  }
}
