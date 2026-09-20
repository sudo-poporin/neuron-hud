import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';

/// Campo de barras horizontales de largo y posicion aleatorios.
///
/// Es la capa ブロックノイズ del diagrama de descomposicion del HUD de Astral
/// Chain, y el efecto firma del sistema: lee como contenido que todavia no
/// resolvio, que es exactamente el trabajo de un esqueleto de carga.
///
/// Las barras son **rayas**, no bloques cuadrados: en la referencia miden uno a
/// tres pixeles de alto sobre un plano grande.
///
/// **El azar se deriva de [seed], no de un `Random` inyectado.** Un `Random`
/// tiene estado y cada llamada lo avanza, asi que consumirlo en `paint` daria
/// un layout distinto en cada repintado — y un painter repinta por motivos que
/// no tienen nada que ver con la animacion: un cambio de tamano, un
/// `MediaQuery` nuevo, el padre reconstruyendose. Con `Random(seed)` fresco
/// adentro de `paint` el layout es estable entre repintados y reproducible en
/// test, y el constructor sigue siendo `const`.
///
/// De paso, quien la use puede derivar la semilla del item —`seed: game.id`— y
/// entonces cada fila de una lista tiene su propio patron.
///
/// **Con `child` en null no pinta nada.** `CustomPaint` sin hijo se dimensiona
/// por su parametro `size`, que por defecto es `Size.zero`.
class BlockNoise extends StatelessWidget {
  /// Campo de barras horizontales de largo y posicion aleatorios.
  const new({
    super.key,
    this.density = 0.35,
    this.color = astralInk,
    this.barHeight = 2,
    this.minBarWidth = 4,
    this.maxBarWidth = 48,
    this.progress,
    this.seed = 0,
    this.child,
  });

  /// Fraccion del area que cubren las barras, de 0 a 1.
  final double density;

  /// Color de las barras.
  final Color color;

  /// Alto de cada barra.
  final double barHeight;

  /// Ancho minimo de una barra.
  final double minBarWidth;

  /// Ancho maximo de una barra.
  final double maxBarWidth;

  /// Cuanto resolvio el elemento, de 0 a 1.
  ///
  /// `null` y 0 pintan el campo completo; 1 no pinta nada. Las barras que
  /// sobreviven no se mueven: el progreso recorta un prefijo del mismo layout.
  ///
  /// Es la polaridad **inversa** a `HoldProgressBorderPainter`, donde 0 no
  /// pinta nada y 1 pinta el perimetro completo: un orquestador que maneje
  /// las dos capas desde el mismo `AnimationController` va a invertir una
  /// animacion en silencio si no lo tiene en cuenta.
  final double? progress;

  /// Semilla del layout.
  final int seed;

  /// Contenido sobre el que se dibujan las barras.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: BlockNoisePainter(
        density: density,
        color: color,
        barHeight: barHeight,
        minBarWidth: minBarWidth,
        maxBarWidth: maxBarWidth,
        progress: progress,
        seed: seed,
      ),
      child: child,
    );
  }
}

/// Pinta el campo de barras de [BlockNoise].
class BlockNoisePainter extends CustomPainter {
  /// Pinta el campo de barras de [BlockNoise].
  const new({
    required this.density,
    required this.color,
    required this.barHeight,
    required this.minBarWidth,
    required this.maxBarWidth,
    required this.progress,
    required this.seed,
  });

  /// Fraccion del area que cubren las barras.
  final double density;

  /// Color de las barras.
  final Color color;

  /// Alto de cada barra.
  final double barHeight;

  /// Ancho minimo de una barra.
  final double minBarWidth;

  /// Ancho maximo de una barra.
  final double maxBarWidth;

  /// Cuanto resolvio el elemento, de 0 a 1.
  final double? progress;

  /// Semilla del layout.
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final remaining = (1 - (progress ?? 0)).clamp(0.0, 1.0);
    if (remaining <= 0) return;
    if (size.isEmpty) return;

    final averageBarArea = (minBarWidth + maxBarWidth) / 2 * barHeight;
    if (averageBarArea <= 0) return;

    final total = (size.width * size.height * density / averageBarArea).round();
    final visible = (total * remaining).round();

    final random = math.Random(seed);
    final paint = Paint()..color = color;

    for (var i = 0; i < total; i++) {
      if (i >= visible) break;

      // El layout es estable porque `random` se siembra igual (`Random(seed)`)
      // en cada `paint`: las barras `0..visible-1` consumen siempre la misma
      // secuencia de tiradas, sin importar hasta donde llegue el loop. Por
      // eso las barras que sobreviven al progreso no se mueven, que es lo que
      // muestran los cuatro frames de la referencia.
      final width =
          minBarWidth + random.nextDouble() * (maxBarWidth - minBarWidth);
      final clampedWidth = math.min(width, size.width);
      final left = random.nextDouble() * (size.width - clampedWidth);
      // Mismo tratamiento que el ancho: sin este clamp, una barra mas alta
      // que la caja deja `top` en 0 y se sale por abajo.
      final clampedHeight = math.min(barHeight, size.height);
      final top = random.nextDouble() * (size.height - clampedHeight);

      canvas.drawRect(
        Rect.fromLTWH(left, top, clampedWidth, clampedHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BlockNoisePainter oldDelegate) =>
      oldDelegate.density != density ||
      oldDelegate.color != color ||
      oldDelegate.barHeight != barHeight ||
      oldDelegate.minBarWidth != minBarWidth ||
      oldDelegate.maxBarWidth != maxBarWidth ||
      oldDelegate.progress != progress ||
      oldDelegate.seed != seed;
}
