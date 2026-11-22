import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';

/// Piezas base del rediseño v2.
///
/// Cada pantalla se arma con estas piezas y no con tarjetas de Material sueltas. Así el
/// espaciado, los radios y el uso del color son los mismos en todas partes, y un ajuste visual
/// se hace en un solo sitio.

/// La cifra protagonista de una pantalla: «Tienes hoy», «Debes en total».
///
/// El signo de pesos va más pequeño y en gris, para que el ojo vaya a la cifra.
class CifraPrincipal extends StatelessWidget {
  const CifraPrincipal({
    required this.etiqueta,
    required this.valor,
    this.debajo = const [],
    super.key,
  });

  final String etiqueta;
  final double valor;

  /// Etiquetas o botones bajo la cifra: «Cuadra con tus bancos».
  final List<Widget> debajo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final negativo = valor < 0;
    final cifra = Formato.pesos(valor.abs()).replaceFirst(r'$', '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: textos.bodyMedium?.copyWith(color: c.tinta2)),
        const SizedBox(height: Espacio.xs),
        Semantics(
          label: '$etiqueta ${Formato.pesos(valor)}',
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: negativo ? r'−$' : r'$',
                  style: Tipo.estilo(26, 600, color: c.tinta2),
                ),
                TextSpan(
                  text: cifra,
                  style: textos.displayLarge?.copyWith(
                    color: negativo ? c.negativo : c.tinta,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (debajo.isNotEmpty) ...[
          const SizedBox(height: Espacio.m),
          Wrap(spacing: Espacio.s, runSpacing: Espacio.s, children: debajo),
        ],
      ],
    );
  }
}

/// Un importe en pesos sin centavos, con el color que le toca.
///
/// Solo lo que entra va en verde. Lo que sale va en tinta normal: en una lista de gastos, que
/// todo sea rojo no dice nada.
class Importe extends StatelessWidget {
  const Importe(
    this.valor, {
    this.estilo,
    this.conSigno = false,
    this.colorear = true,
    super.key,
  });

  final double valor;
  final TextStyle? estilo;

  /// Antepone `+` a lo positivo.
  final bool conSigno;

  /// Pinta de verde lo positivo.
  final bool colorear;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final base = estilo ?? Theme.of(context).textTheme.titleSmall!;
    return Text(
      conSigno ? Formato.pesosConSigno(valor) : Formato.pesos(valor),
      style: base.copyWith(
        fontWeight: FontWeight.w700,
        color: colorear && valor > 0 ? c.positivo : base.color ?? c.tinta,
      ),
      maxLines: 1,
    );
  }
}

/// Superficie blanca y redondeada que agrupa contenido. Sin borde: la separa el fondo.
class Panel extends StatelessWidget {
  const Panel({required this.child, this.relleno, super.key});

  /// Panel de filas separadas por una línea fina.
  Panel.lista({required List<Widget> filas, super.key})
    : relleno = EdgeInsets.zero,
      child = Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            filas[i],
          ],
        ],
      );

  final Widget child;
  final EdgeInsetsGeometry? relleno;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(Radios.panel),
        boxShadow: c.sombra,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radios.panel),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: relleno ?? const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bloque con título y, opcionalmente, una acción a la derecha: «Próximos pagos · 30 días».
class Seccion extends StatelessWidget {
  const Seccion({
    required this.titulo,
    required this.child,
    this.accion,
    this.alTocarAccion,
    this.arriba = Espacio.seccion,
    super.key,
  });

  final String titulo;
  final Widget child;
  final String? accion;
  final VoidCallback? alTocarAccion;

  /// Espacio por encima. La primera sección de una pantalla suele querer menos.
  final double arriba;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: arriba),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(titulo, style: textos.titleMedium),
                  ),
                ),
                if (accion != null)
                  alTocarAccion == null
                      ? Text(accion!, style: textos.labelMedium)
                      : InkWell(
                          onTap: alTocarAccion,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              accion!,
                              style: textos.labelMedium?.copyWith(
                                color: c.tinta2,
                              ),
                            ),
                          ),
                        ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Cuadro redondeado con un icono, como el de la categoría de cada movimiento.
class IconoCaja extends StatelessWidget {
  const IconoCaja(this.icono, {this.tamano = 40, this.color, super.key});

  final IconData icono;
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: c.superficie2,
        borderRadius: BorderRadius.circular(Radios.icono),
      ),
      alignment: Alignment.center,
      child: Icon(icono, size: tamano * 0.48, color: color ?? c.tinta2),
    );
  }
}

/// Fila de una lista: algo a la izquierda, título y subtítulo, e importe a la derecha.
///
/// Es la pieza de Movimientos, Próximos pagos, Deudas y Cuentas.
class Fila extends StatelessWidget {
  const Fila({
    required this.titulo,
    this.inicio,
    this.subtitulo,
    this.etiqueta,
    this.importe,
    this.importeConSigno = false,
    this.debajoDelImporte,
    this.final_,
    this.alTocar,
    super.key,
  });

  final String titulo;

  /// Icono de categoría, fecha o lo que vaya a la izquierda.
  final Widget? inicio;
  final String? subtitulo;

  /// Marca breve junto al título: «Préstamo», «Mismo día».
  final Widget? etiqueta;
  final double? importe;
  final bool importeConSigno;

  /// Texto pequeño bajo el importe: «estimado», «2 dic».
  final String? debajoDelImporte;

  /// Sustituye al importe cuando hace falta otra cosa, como un botón.
  final Widget? final_;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          if (inicio != null) ...[inicio!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        titulo,
                        style: textos.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (etiqueta != null) ...[
                      const SizedBox(width: 6),
                      etiqueta!,
                    ],
                  ],
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    style: textos.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (importe != null || final_ != null) const SizedBox(width: 12),
          if (final_ != null)
            final_!
          else if (importe != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Importe(importe!, conSigno: importeConSigno),
                if (debajoDelImporte != null) ...[
                  const SizedBox(height: 2),
                  Text(debajoDelImporte!, style: textos.bodySmall),
                ],
              ],
            ),
        ],
      ),
    );
    if (alTocar == null) return contenido;
    return InkWell(onTap: alTocar, child: contenido);
  }
}

/// Fecha compacta para la izquierda de una fila: el número grande y el mes debajo.
class FechaCorta extends StatelessWidget {
  const FechaCorta({required this.dia, required this.mes, super.key});

  /// `4`, o un rango como `1–7`.
  final String dia;
  final String mes;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Text(dia, style: Tipo.estilo(17, 700, color: c.tinta, altura: 1.05)),
          Text(
            mes.toUpperCase(),
            style: Tipo.estilo(11, 600, color: c.tinta3, espaciado: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Tono de una etiqueta o un aviso.
enum Tono { suave, positivo, aviso, negativo }

extension _ColoresDelTono on Tono {
  (Color, Color) colores(Colores c) => switch (this) {
    Tono.suave => (c.superficie2, c.tinta2),
    Tono.positivo => (c.positivoFondo, c.positivo),
    Tono.aviso => (c.avisoFondo, c.aviso),
    Tono.negativo => (c.negativoFondo, c.negativo),
  };
}

/// Pastilla de estado: «Cuadra con tus bancos», «Préstamo», «Mismo día».
class Etiqueta extends StatelessWidget {
  const Etiqueta(
    this.texto, {
    this.tono = Tono.suave,
    this.icono,
    this.grande = false,
    this.alTocar,
    super.key,
  });

  final String texto;
  final Tono tono;
  final IconData? icono;

  /// Las grandes van bajo una cifra; las pequeñas, junto al título de una fila.
  final bool grande;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final (fondo, frente) = tono.colores(context.colores);
    final radio = BorderRadius.circular(grande ? 999 : 6);
    final cuerpo = Padding(
      padding: grande
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: grande ? 15 : 12, color: frente),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: Tipo.estilo(
              grande ? 13 : 11,
              grande ? 600 : 700,
              color: frente,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: fondo,
      borderRadius: radio,
      child: alTocar == null
          ? cuerpo
          : InkWell(onTap: alTocar, borderRadius: radio, child: cuerpo),
    );
  }
}

/// Aviso en una frase: lo que antes había que deducir de varias cifras.
class CajaAviso extends StatelessWidget {
  const CajaAviso({
    required this.texto,
    this.tono = Tono.aviso,
    this.icono,
    super.key,
  });

  /// Admite negritas: `TextSpan(children: [...])`.
  final InlineSpan texto;
  final Tono tono;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final (fondo, frente) = tono.colores(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tono == Tono.suave ? c.superficie2 : fondo,
        borderRadius: BorderRadius.circular(Radios.medio),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono ?? Icons.info_outline, size: 20, color: frente),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              texto,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se ve cuando una lista está vacía: qué irá aquí y cómo empezar.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.accion,
    this.alTocarAccion,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final String? accion;
  final VoidCallback? alTocarAccion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconoCaja(icono, tamano: 56),
          const SizedBox(height: Espacio.l),
          Text(titulo, style: textos.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Espacio.s),
          Text(
            texto,
            style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
            textAlign: TextAlign.center,
          ),
          if (accion != null) ...[
            const SizedBox(height: Espacio.xl),
            FilledButton(onPressed: alTocarAccion, child: Text(accion!)),
          ],
        ],
      ),
    );
  }
}

/// Abre una hoja inferior con el estilo de la app: título, contenido desplazable y margen
/// para el teclado.
Future<T?> abrirHoja<T>(
  BuildContext context, {
  required String titulo,
  required WidgetBuilder contenido,
  String? subtitulo,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (contexto) {
      final textos = Theme.of(contexto).textTheme;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(contexto).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: textos.titleLarge),
              if (subtitulo != null) ...[
                const SizedBox(height: Espacio.xs),
                Text(
                  subtitulo,
                  style: textos.bodyMedium?.copyWith(
                    color: contexto.colores.tinta2,
                  ),
                ),
              ],
              const SizedBox(height: Espacio.l),
              contenido(contexto),
            ],
          ),
        ),
      );
    },
  );
}
