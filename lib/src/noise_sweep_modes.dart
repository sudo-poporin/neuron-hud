part of 'noise_sweep.dart';

/// Como pinta [NoiseSweepPainter] cada uno de sus dos modos.
///
/// Viven aparte del painter porque son dos caminos que no se cruzan: `paint`
/// elige uno y el otro no corre. El painter se queda con lo que comparten, que
/// son sus parametros y cuando hay que repintar.
extension _NoiseSweepModes on NoiseSweepPainter {
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

    // **Recorte, y no intersectar el Rect como hace [_drawInside].** Un jiron
    // arranca en negativo y termina pasado el borde por como se calcula su
    // posicion, y ademas lleva un `MaskFilter.blur` que lo estira mas alla de
    // su propio rectangulo: recortar el rect dejaria el desenfoque igual
    // pintando encima de los vecinos. `CustomPaint` no recorta solo.
    //
    // Una sola vez alrededor del bucle y no por jiron: es el mismo recorte para
    // los seis.
    canvas
      ..save()
      ..clipRect(Offset.zero & size);

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
      // **La travesia se extiende medio largo a cada lado de la caja.** El
      // rectangulo se centra en `along` y mide `lengthFactor`, asi que con el
      // recorrido en 0..1 el jiron todavia esta medio adentro cuando el `% 1`
      // lo manda al otro extremo: salta de medio visible a la derecha a medio
      // visible a la izquierda, de un frame al otro.
      //
      // Mapeando a `-lengthFactor/2 .. 1 + lengthFactor/2`, entra desde afuera
      // y sale del todo antes de wrapear. Es otra continuidad que la del borde
      // del ciclo, que ya la dan las vueltas enteras: aquella es entre t=1 y
      // t=0, esta es a mitad de vuelta.
      final extended = -lengthFactor / 2 + travelled * (1 + lengthFactor);
      final along = _forward ? extended : 1 - extended;

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

    canvas.restore();
  }
}
