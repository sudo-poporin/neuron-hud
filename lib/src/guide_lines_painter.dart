part of 'guide_lines.dart';

/// Pinta las guias de [GuideLines].
class GuideLinesPainter extends CustomPainter {
  /// Pinta las guias de [GuideLines].
  const new({
    required this.verticals,
    required this.horizontals,
    required this.tickCount,
    required this.tickLength,
    required this.strokeWidth,
    required this.color,
    required this.overflow,
    required this.progress,
    required this.drift,
    required this.seed,
  });

  /// Cantidad de lineas verticales.
  final int verticals;

  /// Cantidad de lineas horizontales.
  final int horizontals;

  /// Marcas de tick por linea.
  final int tickCount;

  /// Largo de cada marca de tick.
  final double tickLength;

  /// Ancho del trazo.
  final double strokeWidth;

  /// Color de las lineas.
  final Color color;

  /// Pixeles de desborde a cada lado.
  final double overflow;

  /// Cuanto resolvio el elemento, de 0 a 1.
  final double? progress;

  /// Cuanto se corren las lineas de su posicion, en pixeles logicos.
  final double drift;

  /// Semilla de la posicion de las lineas.
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final remaining = (1 - (progress ?? 0)).clamp(0.0, 1.0);
    if (remaining <= 0) return;

    final random = math.Random(seed);
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * remaining)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final half = tickLength / 2;

    // Las posiciones de las verticales se consumen del `Random` antes que
    // las de las horizontales: cambiar `verticals` corre todas las
    // posiciones de las horizontales. Es correcto (mismo patron que los tres
    // `nextDouble` de `BlockNoisePainter`), pero es una trampa sin avisar.
    for (var i = 0; i < verticals; i++) {
      final x = random.nextDouble() * size.width + drift;

      canvas.drawLine(
        Offset(x, -overflow),
        Offset(x, size.height + overflow),
        paint,
      );

      for (var tick = 1; tick <= tickCount; tick++) {
        final y = size.height * tick / (tickCount + 1);
        canvas.drawLine(Offset(x - half, y), Offset(x + half, y), paint);
      }
    }

    for (var i = 0; i < horizontals; i++) {
      final y = random.nextDouble() * size.height + drift;

      canvas.drawLine(
        Offset(-overflow, y),
        Offset(size.width + overflow, y),
        paint,
      );

      for (var tick = 1; tick <= tickCount; tick++) {
        final x = size.width * tick / (tickCount + 1);
        canvas.drawLine(Offset(x, y - half), Offset(x, y + half), paint);
      }
    }
  }

  @override
  bool shouldRepaint(GuideLinesPainter oldDelegate) =>
      oldDelegate.verticals != verticals ||
      oldDelegate.horizontals != horizontals ||
      oldDelegate.tickCount != tickCount ||
      oldDelegate.tickLength != tickLength ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color ||
      oldDelegate.overflow != overflow ||
      oldDelegate.progress != progress ||
      oldDelegate.drift != drift ||
      oldDelegate.seed != seed;
}
