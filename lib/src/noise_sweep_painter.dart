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

  void _paintBand(Canvas canvas, Size size) {
    final extent = _horizontal ? size.width : size.height;
    final band = bandWidth.clamp(0.0, 1.0) * extent;
    if (band <= 0) return;

    // La banda entra desde fuera de la caja y sale por el otro lado, asi que
    // recorre extent + band y arranca en -band.
    final travel = extent + band;
    final head = _forward ? -band + travel * t : extent - travel * t;

    _paintTrail(canvas, size, head: head, band: band, extent: extent);

    final rect = _horizontal
        ? Rect.fromLTWH(head, 0, band, size.height)
        : Rect.fromLTWH(0, head, size.width, band);

    // Un rectangulo de color pleno se lee como una tapa; el gradiente es lo
    // que lee como barrido.
    final gradient = LinearGradient(
      begin: _horizontal ? Alignment.centerLeft : Alignment.topCenter,
      end: _horizontal ? Alignment.centerRight : Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
    );

    _drawInside(canvas, size, rect: rect, gradient: gradient);
  }

  /// Dibuja [rect] recortado a la caja, con el gradiente anclado al rect entero.
  ///
  /// **Ni la banda ni la estela pueden salirse del marco.** `CustomPaint` no
  /// clipea, y las dos se pasan por diseño: la banda arranca en `-band` para
  /// entrar desde afuera, y la estela se extiende hacia atras todo su largo. Sin
  /// esto, lo que sobra se pinta fuera de la caja y cruza el marco que dibujan
  /// las esquinas.
  ///
  /// **El shader se crea sobre el rect entero y no sobre el recortado**, o el
  /// gradiente se recomprimiria dentro de lo que quedo visible: la estela
  /// llegaria al color pleno en el borde de la caja en vez de en la cabeza de la
  /// banda, y se veria acelerar al entrar y al salir.
  ///
  /// El recorrido no cambia: lo que cambia es cuanto de el se pinta.
  void _drawInside(
    Canvas canvas,
    Size size, {
    required Rect rect,
    required Gradient gradient,
  }) {
    final visible = rect.intersect(Offset.zero & size);
    if (visible.isEmpty) return;

    canvas.drawRect(visible, Paint()..shader = gradient.createShader(rect));
  }

  /// Pinta la estela detras de la banda, del lado por el que ya paso.
  ///
  /// Va **antes** que la banda para que la banda quede encima: la estela llega
  /// al color pleno en el borde que las une, y pintada despues le comeria la
  /// cabeza.
  void _paintTrail(
    Canvas canvas,
    Size size, {
    required double head,
    required double band,
    required double extent,
  }) {
    final length = trail.clamp(0.0, 1.0) * extent;
    if (length <= 0) return;

    // Detras es el lado por el que la banda ya paso, y eso depende de hacia
    // donde barre.
    final start = _forward ? head - length : head + band;

    final rect = _horizontal
        ? Rect.fromLTWH(start, 0, length, size.height)
        : Rect.fromLTWH(0, start, size.width, length);

    // Del transparente al color en el extremo que toca la banda: la estela se
    // apaga a medida que se aleja de donde esta la cabeza ahora.
    final fading = [color.withValues(alpha: 0), color];

    final gradient = LinearGradient(
      begin: _horizontal ? Alignment.centerLeft : Alignment.topCenter,
      end: _horizontal ? Alignment.centerRight : Alignment.bottomCenter,
      colors: _forward ? fading : fading.reversed.toList(),
    );

    _drawInside(canvas, size, rect: rect, gradient: gradient);
  }

  void _paintWisps(Canvas canvas, Size size) {
    final random = math.Random(seed);

    for (var i = 0; i < wispCount; i++) {
      // Cada jiron tiene su fase, su velocidad, su travesia, su largo y su
      // opacidad: sin eso los seis derivan en bloque y se lee como una sola
      // banda, que es justo lo que el sandstorm no es.
      final phase = random.nextDouble();
      // Vueltas **enteras** y no una velocidad fraccionaria: el controller
      // wrapea de 1 a 0 en cada ciclo, y con `speed` fraccionaria
      // `(phase + t * speed) % 1` no coincide entre los dos extremos — el
      // jiron teletransportaba de 6 a 30 px en cada vuelta. Con un entero, t=1
      // y t=0 dan la misma posicion.
      final laps = 1 + random.nextInt(2);
      final across = random.nextDouble();
      final lengthFactor = 0.15 + random.nextDouble() * 0.25;
      final alpha = 0.03 + random.nextDouble() * 0.05;

      final travelled = (phase + t * laps) % 1;
      final along = _forward ? travelled : 1 - travelled;

      final rect = _horizontal
          ? Rect.fromLTWH(
              along * size.width - size.width * lengthFactor / 2,
              across * size.height,
              size.width * lengthFactor,
              math.max(1, size.height * 0.05),
            )
          : Rect.fromLTWH(
              across * size.width,
              along * size.height - size.height * lengthFactor / 2,
              math.max(1, size.width * 0.05),
              size.height * lengthFactor,
            );

      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: color.a * alpha)
          // Sin el blur son rectangulos duros, y el sandstorm son jirones.
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
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
