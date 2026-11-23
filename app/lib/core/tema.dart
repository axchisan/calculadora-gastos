import 'package:flutter/material.dart';

/// Colores de la aplicación, los mismos del prototipo aprobado del rediseño v2.
///
/// Neutro por defecto: tinta casi negra sobre un gris muy claro, y superficies blancas sin
/// borde. El color solo aparece cuando significa algo (lo que entró, lo que está mal, lo que
/// requiere atención). El rediseño nació de que todo resaltaba a la vez y nada se distinguía.
@immutable
class Colores extends ThemeExtension<Colores> {
  const Colores({
    required this.fondo,
    required this.superficie,
    required this.superficie2,
    required this.tinta,
    required this.tinta2,
    required this.tinta3,
    required this.linea,
    required this.acento,
    required this.sobreAcento,
    required this.positivo,
    required this.positivoFondo,
    required this.negativo,
    required this.negativoFondo,
    required this.aviso,
    required this.avisoFondo,
    required this.sombra,
  });

  /// Fondo de las pantallas.
  final Color fondo;

  /// Paneles y hojas: blanco en el tema claro.
  final Color superficie;

  /// Rellenos discretos: campos, iconos de categoría, pistas de las barras.
  final Color superficie2;

  /// Texto principal.
  final Color tinta;

  /// Texto secundario.
  final Color tinta2;

  /// Texto terciario: fechas, subtítulos, ejes.
  final Color tinta3;

  /// Separadores.
  final Color linea;

  /// Botones principales y lo seleccionado. Es la misma tinta: un acento de color sería un
  /// color más compitiendo con los que sí significan algo.
  final Color acento;
  final Color sobreAcento;

  /// Lo que entró y lo que se completó.
  final Color positivo;
  final Color positivoFondo;

  /// Saldo negativo y pagos vencidos.
  final Color negativo;
  final Color negativoFondo;

  /// Lo que requiere atención sin ser un error.
  final Color aviso;
  final Color avisoFondo;

  /// Sombra de los paneles. Transparente en el tema oscuro, donde no se ve y solo ensucia.
  final List<BoxShadow> sombra;

  static const claro = Colores(
    fondo: Color(0xFFF4F5F2),
    superficie: Color(0xFFFFFFFF),
    superficie2: Color(0xFFECEEEA),
    tinta: Color(0xFF151816),
    tinta2: Color(0xFF5C635F),
    tinta3: Color(0xFF8F9692),
    linea: Color(0xFFE3E5E0),
    acento: Color(0xFF151816),
    sobreAcento: Color(0xFFFFFFFF),
    positivo: Color(0xFF2C7650),
    positivoFondo: Color(0xFFE4F1E9),
    negativo: Color(0xFFBE3F2B),
    negativoFondo: Color(0xFFF8E7E3),
    aviso: Color(0xFF9A6412),
    avisoFondo: Color(0xFFF6ECD8),
    sombra: [
      BoxShadow(color: Color(0x0D151816), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0F151816), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  static const oscuro = Colores(
    fondo: Color(0xFF0E100F),
    superficie: Color(0xFF171A19),
    superficie2: Color(0xFF1F2321),
    tinta: Color(0xFFEDF0EE),
    tinta2: Color(0xFFA4ABA7),
    tinta3: Color(0xFF737A76),
    linea: Color(0xFF262A28),
    acento: Color(0xFFEDF0EE),
    sobreAcento: Color(0xFF0E100F),
    positivo: Color(0xFF72C49B),
    positivoFondo: Color(0xFF16302A),
    negativo: Color(0xFFF08C79),
    negativoFondo: Color(0xFF3A1D18),
    aviso: Color(0xFFE2B463),
    avisoFondo: Color(0xFF352A15),
    sombra: [],
  );

  /// Los colores del tema activo.
  static Colores de(BuildContext context) =>
      Theme.of(context).extension<Colores>() ?? claro;

  @override
  Colores copyWith({Color? fondo, Color? superficie, Color? tinta}) => Colores(
    fondo: fondo ?? this.fondo,
    superficie: superficie ?? this.superficie,
    superficie2: superficie2,
    tinta: tinta ?? this.tinta,
    tinta2: tinta2,
    tinta3: tinta3,
    linea: linea,
    acento: acento,
    sobreAcento: sobreAcento,
    positivo: positivo,
    positivoFondo: positivoFondo,
    negativo: negativo,
    negativoFondo: negativoFondo,
    aviso: aviso,
    avisoFondo: avisoFondo,
    sombra: sombra,
  );

  @override
  Colores lerp(Colores? otro, double t) {
    if (otro == null) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return Colores(
      fondo: m(fondo, otro.fondo),
      superficie: m(superficie, otro.superficie),
      superficie2: m(superficie2, otro.superficie2),
      tinta: m(tinta, otro.tinta),
      tinta2: m(tinta2, otro.tinta2),
      tinta3: m(tinta3, otro.tinta3),
      linea: m(linea, otro.linea),
      acento: m(acento, otro.acento),
      sobreAcento: m(sobreAcento, otro.sobreAcento),
      positivo: m(positivo, otro.positivo),
      positivoFondo: m(positivoFondo, otro.positivoFondo),
      negativo: m(negativo, otro.negativo),
      negativoFondo: m(negativoFondo, otro.negativoFondo),
      aviso: m(aviso, otro.aviso),
      avisoFondo: m(avisoFondo, otro.avisoFondo),
      sombra: t < 0.5 ? sombra : otro.sombra,
    );
  }
}

/// Atajo: `context.colores.tinta2`.
extension ColoresDelContexto on BuildContext {
  Colores get colores => Colores.de(this);
}

/// Espaciado. Pocos valores y siempre los mismos: el espacio es lo que agrupa y separa, no los
/// bordes.
class Espacio {
  const Espacio._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double seccion = 30;

  /// Margen lateral de las pantallas.
  static const double lateral = 20;
}

/// Radios de las esquinas.
class Radios {
  const Radios._();

  static const double panel = 20;
  static const double medio = 14;
  static const double icono = 12;
  static const double hoja = 24;
}

/// Tipografía: Inter en pesos fijos, con cifras tabulares para que los importes se alineen.
class Tipo {
  const Tipo._();

  static const String familia = 'Inter';

  static TextStyle estilo(
    double tamano,
    int peso, {
    double? espaciado,
    double? altura,
    Color? color,
  }) => TextStyle(
    fontFamily: familia,
    fontSize: tamano,
    fontWeight: FontWeight.values[(peso ~/ 100) - 1],
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: espaciado,
    height: altura,
    color: color,
  );

  static TextTheme textos(Colores c) => TextTheme(
    // La cifra protagonista de cada pantalla.
    displayLarge: estilo(44, 700, espaciado: -1.5, altura: 1.1, color: c.tinta),
    displayMedium: estilo(
      36,
      700,
      espaciado: -1.2,
      altura: 1.1,
      color: c.tinta,
    ),
    displaySmall: estilo(30, 700, espaciado: -0.9, color: c.tinta),
    // Títulos de pantalla.
    headlineLarge: estilo(28, 700, espaciado: -0.7, color: c.tinta),
    headlineMedium: estilo(26, 700, espaciado: -0.6, color: c.tinta),
    headlineSmall: estilo(22, 700, espaciado: -0.4, color: c.tinta),
    // Títulos de hojas, de secciones y de filas.
    titleLarge: estilo(20, 700, espaciado: -0.3, color: c.tinta),
    titleMedium: estilo(17, 700, espaciado: -0.15, color: c.tinta),
    titleSmall: estilo(15, 600, color: c.tinta),
    bodyLarge: estilo(15, 500, altura: 1.4, color: c.tinta),
    bodyMedium: estilo(14, 500, altura: 1.45, color: c.tinta),
    bodySmall: estilo(13, 500, altura: 1.4, color: c.tinta3),
    labelLarge: estilo(15, 700, color: c.tinta),
    labelMedium: estilo(13, 600, color: c.tinta2),
    labelSmall: estilo(11, 700, espaciado: 0.3, color: c.tinta3),
  );
}

/// Tema visual de la aplicación.
///
/// Los colores del dinero no son decorativos: distinguir de un vistazo lo pagado de lo
/// pendiente y el saldo positivo del negativo es la función principal de la pantalla. Por eso
/// se usan poco, para que cuando aparezcan se vean.
class Tema {
  const Tema._();

  /// Verde: dinero que entró, gastos pagados, metas cumplidas.
  static const Color positivo = Color(0xFF2C7650);

  /// Ámbar: pendiente de pagar. No es un error, pero exige atención.
  static const Color pendiente = Color(0xFF9A6412);

  /// Rojo: saldo negativo, pagos vencidos.
  static const Color negativo = Color(0xFFBE3F2B);

  /// Azul: información neutra, como los días de trabajo remoto.
  static const Color neutro = Color(0xFF3456D6);

  static ThemeData claro() => _construir(Brightness.light, Colores.claro);

  static ThemeData oscuro() => _construir(Brightness.dark, Colores.oscuro);

  static ThemeData _construir(Brightness brillo, Colores c) {
    final esquema = ColorScheme(
      brightness: brillo,
      primary: c.acento,
      onPrimary: c.sobreAcento,
      primaryContainer: c.superficie2,
      onPrimaryContainer: c.tinta,
      secondary: c.tinta2,
      onSecondary: c.superficie,
      secondaryContainer: c.superficie2,
      onSecondaryContainer: c.tinta,
      tertiary: c.positivo,
      onTertiary: c.superficie,
      tertiaryContainer: c.positivoFondo,
      onTertiaryContainer: c.positivo,
      error: c.negativo,
      onError: c.superficie,
      errorContainer: c.negativoFondo,
      onErrorContainer: c.negativo,
      surface: c.fondo,
      onSurface: c.tinta,
      onSurfaceVariant: c.tinta2,
      surfaceContainerLowest: c.superficie,
      surfaceContainerLow: c.superficie,
      surfaceContainer: c.superficie,
      surfaceContainerHigh: c.superficie2,
      surfaceContainerHighest: c.superficie2,
      outline: c.tinta3,
      outlineVariant: c.linea,
      inverseSurface: c.tinta,
      onInverseSurface: c.fondo,
      inversePrimary: c.superficie,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
    final textos = Tipo.textos(c);
    final redondo = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radios.medio),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      extensions: [c],
      fontFamily: Tipo.familia,
      textTheme: textos,
      scaffoldBackgroundColor: c.fondo,
      canvasColor: c.fondo,
      dividerColor: c.linea,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.fondo,
        foregroundColor: c.tinta,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textos.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: c.superficie,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.panel),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: c.linea, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: c.superficie2,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => Tipo.estilo(
            11,
            estados.contains(WidgetState.selected) ? 700 : 600,
            color: estados.contains(WidgetState.selected) ? c.tinta : c.tinta3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            size: 22,
            color: estados.contains(WidgetState.selected) ? c.tinta : c.tinta3,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.fondo,
        indicatorColor: c.superficie2,
        selectedIconTheme: IconThemeData(color: c.tinta),
        unselectedIconTheme: IconThemeData(color: c.tinta3),
        selectedLabelTextStyle: Tipo.estilo(12, 700, color: c.tinta),
        unselectedLabelTextStyle: Tipo.estilo(12, 600, color: c.tinta3),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.acento,
        foregroundColor: c.sobreAcento,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: Tipo.estilo(15, 700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.superficie2,
        labelStyle: Tipo.estilo(15, 500, color: c.tinta3),
        floatingLabelStyle: Tipo.estilo(13, 600, color: c.tinta2),
        hintStyle: Tipo.estilo(15, 500, color: c.tinta3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radios.medio),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radios.medio),
          borderSide: BorderSide(color: c.tinta2, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        // Sin colores aquí: este tema también aplica a `FilledButton.tonal`, que debe salir gris
        // (contenedor secundario) y no negro como el principal. Los colores salen del esquema.
        style: FilledButton.styleFrom(
          // Solo la altura, cómoda para el pulgar. Aquí estuvo 'Size.fromHeight(52)', que además
          // fija el ancho mínimo en infinito: dentro de una fila el botón desbordaba, y como las
          // tarjetas recortan su contenido, desaparecía sin dejar rastro. En publicación no se
          // ven las rayas de desbordamiento, así que el botón de confirmar un pago detectado
          // llevaba semanas invisible aunque seguía estando ahí y respondiendo al toque.
          // El ancho lo pone quien coloca el botón: una columna estirada o un Expanded.
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: Tipo.estilo(15, 700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.tinta,
          side: BorderSide(color: c.linea),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: Tipo.estilo(15, 700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.tinta,
          textStyle: Tipo.estilo(14, 700),
          shape: redondo,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.tinta2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.superficie2,
          foregroundColor: c.tinta2,
          selectedBackgroundColor: c.superficie,
          selectedForegroundColor: c.tinta,
          side: BorderSide(color: c.superficie2, width: 3),
          textStyle: Tipo.estilo(13, 600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.superficie2,
        selectedColor: c.acento,
        disabledColor: c.superficie2,
        labelStyle: Tipo.estilo(13, 600, color: c.tinta2),
        secondaryLabelStyle: Tipo.estilo(13, 600, color: c.sobreAcento),
        checkmarkColor: c.sobreAcento,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.superficie),
        trackColor: WidgetStateProperty.resolveWith(
          (estados) =>
              estados.contains(WidgetState.selected) ? c.acento : c.superficie2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? c.acento
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.sobreAcento),
        side: BorderSide(color: c.tinta3, width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.tinta,
        linearTrackColor: c.superficie2,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.superficie,
        showDragHandle: true,
        dragHandleColor: c.linea,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radios.hoja),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.panel),
        ),
        titleTextStyle: textos.titleLarge,
        contentTextStyle: textos.bodyMedium?.copyWith(color: c.tinta2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.medio),
        ),
        textStyle: Tipo.estilo(15, 500, color: c.tinta),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.tinta,
        contentTextStyle: Tipo.estilo(14, 600, color: c.fondo),
        actionTextColor: c.fondo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.medio),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: c.tinta2,
        titleTextStyle: textos.titleSmall,
        subtitleTextStyle: textos.bodySmall,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.tinta,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: Tipo.estilo(12, 600, color: c.fondo),
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
