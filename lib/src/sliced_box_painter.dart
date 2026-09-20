part of 'sliced_box.dart';

/// Pinta las lineas largas hacia los lados de [SlicedBox].
class SlicedStreaksPainter extends CustomPainter {
  /// Pinta las lineas largas hacia los lados de [SlicedBox].
  const new({
    required this.bands,
    required this.color,
    required this.overflow,
    required this.strokeWidth,
  });

  /// Las bandas, en fracciones del alto de la caja.
  final List<({double top, double height})> bands;

  /// Color de las lineas.
  final Color color;

  /// Pixeles que las lineas se extienden mas alla de la caja, de los dos lados.
  final double overflow;

  /// Ancho del trazo.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final band in bands) {
      final top = band.top * size.height;
      final bottom = (band.top + band.height) * size.height;

      canvas
        ..drawLine(
          Offset(-overflow, top),
          Offset(size.width + overflow, top),
          paint,
        )
        ..drawLine(
          Offset(-overflow, bottom),
          Offset(size.width + overflow, bottom),
          paint,
        );
    }
  }

  // `RenderCustomPaint.hitTestSelf` es `_painter!.hitTest(position) ?? true`:
  // un `CustomPaint` con `painter` **absorbe los taps por default**. Y este va
  // en un `Positioned.fill` arriba de todo, asi que sin esto se comia cada tap
  // durante los 90 ms de la rafaga.
  //
  // La asimetria es contraintuitiva y vale anotarla: en `hitTestChildren` el
  // `foregroundPainter` es `?? false`, o sea que **no** absorbe. Las cuatro
  // capas base y `NoiseSweep`, que usan ese slot, no tienen el problema.
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(SlicedStreaksPainter oldDelegate) =>
      // listEquals y no identidad: la lista se arma de nuevo en cada frame.
      !listEquals(oldDelegate.bands, bands) ||
      oldDelegate.color != color ||
      oldDelegate.overflow != overflow ||
      oldDelegate.strokeWidth != strokeWidth;
}
