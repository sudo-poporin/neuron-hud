import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';

part 'guide_lines_painter.dart';

/// Lineas guia con marcas de tick, que pueden desbordar el hijo.
///
/// Es la capa グリッド del diagrama de descomposicion del HUD de Astral Chain, y
/// es **andamio**: en `hud_inanimation.mp4` —el video del blog oficial de
/// PlatinumGames en https://www.platinumgames.com/official-blog/article/10422—
/// llega antes que cualquier contenido, y se va cuando el elemento resolvio.
///
/// **Esta separado de `TechFrame` justamente porque desborda.** En la
/// referencia las lineas cruzan la pantalla entera, no la caja del elemento.
/// Con [overflow] en 0 se comporta como una capa interna; con [overflow]
/// positivo hay que envolverla en algo que **no clipee**, o el desborde se
/// recorta y el efecto se pierde.
///
/// Que llegue primero no es una curva propia de este widget: es el orden de
/// fases que impone el orquestador de la secuencia.
///
/// **Con `child` en null no pinta nada.** `CustomPaint` sin hijo se dimensiona
/// por su parametro `size`, que por defecto es `Size.zero`.
class GuideLines extends StatelessWidget {
  /// Lineas guia con marcas de tick, que pueden desbordar el hijo.
  const new({
    super.key,
    this.verticals = 2,
    this.horizontals = 0,
    this.tickCount = 3,
    this.tickLength = 4,
    this.strokeWidth = 1,
    this.color = astralInkDim,
    this.overflow = 0,
    this.progress,
    this.drift = 0,
    this.seed = 0,
    this.child,
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

  /// Pixeles que las lineas se extienden mas alla del hijo, de los dos lados.
  ///
  /// Un valor negativo hace lo contrario de lo que dice el nombre: acorta la
  /// linea hacia adentro de la caja en vez de extenderla.
  final double overflow;

  /// Cuanto resolvio el elemento, de 0 a 1.
  ///
  /// `null` y 0 pintan las guias completas; 1 no pinta nada. Es la polaridad
  /// **inversa** a `HoldProgressBorderPainter`, donde 0 no pinta nada y 1
  /// pinta el perimetro completo: un orquestador que maneje las dos capas
  /// desde el mismo `AnimationController` va a invertir una animacion en
  /// silencio si no lo tiene en cuenta.
  final double? progress;

  /// Cuanto se corren las lineas de su posicion, en pixeles logicos.
  ///
  /// Las verticales en x y las horizontales en y. Positivo o negativo.
  ///
  /// **Es un desplazamiento y no una semilla nueva.** Reseedear reparte las
  /// lineas en otro lado y eso lee como un salto; correrlas unos pocos pixeles
  /// las deja donde estaban, apenas moviendose.
  ///
  /// **Este widget no tiene reloj**, igual que las otras tres capas: derivan su
  /// layout de sus parametros y no se mueven solas. Quien
  /// quiera verlas derivar le mueve este valor desde afuera, que es lo que hace
  /// `NeuronGuideDrift`.
  final double drift;

  /// Semilla de la posicion de las lineas.
  final int seed;

  /// Contenido sobre el que se dibujan las guias.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: GuideLinesPainter(
        verticals: verticals,
        horizontals: horizontals,
        tickCount: tickCount,
        tickLength: tickLength,
        strokeWidth: strokeWidth,
        color: color,
        overflow: overflow,
        progress: progress,
        drift: drift,
        seed: seed,
      ),
      child: child,
    );
  }
}
