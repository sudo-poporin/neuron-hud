part of 'expand_line.dart';

/// Pinta la linea del primer tramo de [ExpandLine].
class ExpandLinePainter extends CustomPainter {
  /// Pinta la linea del primer tramo de [ExpandLine].
  const new({
    required this.color,
    required this.lineHeight,
    required this.alignment,
    required this.opacity,
  });

  /// Color de la linea.
  final Color color;

  /// Alto de la linea.
  final double lineHeight;

  /// Donde cae la linea dentro de la caja.
  final Alignment alignment;

  /// Cuanto se ve la linea, de 0 a 1.
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || lineHeight <= 0 || size.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: color.a * opacity.clamp(0.0, 1.0));
    // `alignment.y` va de -1 arriba a 1 abajo: es la misma cuenta que hace
    // `Alignment.inscribe` para ubicar al hijo adentro de la caja recortada, asi
    // que la linea cae justo donde el panel va a crecer.
    final top = (size.height - lineHeight) * (alignment.y + 1) / 2;

    canvas.drawRect(Rect.fromLTWH(0, top, size.width, lineHeight), paint);
  }

  @override
  bool shouldRepaint(ExpandLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.lineHeight != lineHeight ||
      oldDelegate.alignment != alignment ||
      oldDelegate.opacity != opacity;
}
