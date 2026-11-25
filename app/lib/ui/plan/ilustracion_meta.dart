import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Borgoña: el color con el que se dibuja la meta mientras no tenga foto.
const Color colorBorgona = Color(0xFF6D1F33);

/// La imagen de una meta: la foto que eligió el usuario o, si no hay, un teléfono dibujado que
/// se va llenando de color a medida que se ahorra.
class IlustracionMeta extends StatelessWidget {
  const IlustracionMeta({
    required this.progreso,
    this.foto,
    this.alto = 150,
    super.key,
  });

  /// De 0 a 1.
  final double progreso;
  final Uint8List? foto;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final foto = this.foto;
    if (foto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.memory(
          foto,
          height: alto,
          width: alto * 0.75,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return SizedBox(
      height: alto,
      width: alto * 0.52,
      child: CustomPaint(painter: _Telefono(progreso.clamp(0, 1).toDouble())),
    );
  }
}

/// La espalda de un teléfono: cuerpo redondeado, módulo de cámaras y el color subiendo desde
/// abajo según el progreso. Un dibujo genérico, no el de ningún modelo concreto.
class _Telefono extends CustomPainter {
  _Telefono(this.progreso);

  final double progreso;

  @override
  void paint(Canvas canvas, Size size) {
    final cuerpo = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.18),
    );
    // Lo que falta, en un tono pálido del mismo color.
    canvas.drawRRect(
      cuerpo,
      Paint()..color = colorBorgona.withValues(alpha: 0.16),
    );
    // Lo ahorrado sube desde abajo.
    canvas.save();
    canvas.clipRRect(cuerpo);
    final alto = size.height * progreso;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - alto, size.width, alto),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A2A43), colorBorgona],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
    canvas.drawRRect(
      cuerpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colorBorgona.withValues(alpha: 0.55),
    );

    // Módulo de cámaras.
    final lado = size.width * 0.46;
    final modulo = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.width * 0.08, lado, lado),
      Radius.circular(lado * 0.26),
    );
    canvas.drawRRect(
      modulo,
      Paint()..color = const Color(0xFF3E1220).withValues(alpha: 0.85),
    );
    final r = lado * 0.17;
    final lente = Paint()..color = const Color(0xFF15060B);
    final brillo = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (final c in [
      Offset(modulo.left + lado * 0.3, modulo.top + lado * 0.3),
      Offset(modulo.left + lado * 0.3, modulo.top + lado * 0.72),
      Offset(modulo.left + lado * 0.7, modulo.top + lado * 0.51),
    ]) {
      canvas.drawCircle(c, r, lente);
      canvas.drawCircle(c.translate(-r * 0.3, -r * 0.3), r * 0.25, brillo);
    }
    canvas.drawCircle(
      Offset(modulo.left + lado * 0.72, modulo.top + lado * 0.18),
      r * 0.35,
      Paint()..color = const Color(0xFFF3E6C8),
    );
  }

  @override
  bool shouldRepaint(_Telefono old) => old.progreso != progreso;
}
