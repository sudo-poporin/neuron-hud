part of 'noise_sweep.dart';

/// Pinta el barrido de [NoiseSweep], en cualquiera de sus dos modos.
class NoiseSweepPainter extends CustomPainter {
  /// Pinta el barrido de [NoiseSweep].
  const new({
    required this.t,
    required this.mode,
    required this.color,
    required this.bandWidth,
    required this.trail,
    required this.direction,
    required this.wispCount,
    required this.seed,
  });

  /// Cuanto avanzo el barrido en su vuelta, de 0 a 1.
  final double t;

  /// Que se pinta.
  final NoiseSweepMode mode;

  /// Color del barrido.
  final Color color;

  /// Ancho de la banda como fraccion del eje.
  final double bandWidth;

  /// Largo de la estela detras de la banda, como fraccion del eje.
  final double trail;

  /// Hacia donde barre.
  final AxisDirection direction;

  /// Cantidad de jirones del modo ambiente.
  final int wispCount;

  /// Semilla del campo de jirones.
  final int seed;

  bool get _horizontal => axisDirectionToAxis(direction) == Axis.horizontal;

  bool get _forward =>
      direction == AxisDirection.right || direction == AxisDirection.down;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    switch (mode) {
      case NoiseSweepMode.progress:
        _paintBand(canvas, size);
      case NoiseSweepMode.ambient:
        _paintWisps(canvas, size);
    }
  }

  @override
  bool shouldRepaint(NoiseSweepPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.mode != mode ||
      oldDelegate.color != color ||
      oldDelegate.bandWidth != bandWidth ||
      oldDelegate.trail != trail ||
      oldDelegate.direction != direction ||
      oldDelegate.wispCount != wispCount ||
      oldDelegate.seed != seed;
}
