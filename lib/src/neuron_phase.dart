part of 'neuron_timeline.dart';

/// Las fases de un revelado, en el orden en que corren.
///
/// Salen de `logo_animation.mp4` y de `hud_inanimation.mp4`, los videos del blog
/// oficial de PlatinumGames en
/// https://www.platinumgames.com/official-blog/article/10397. Las tres primeras
/// son la **formacion** del andamio y las cuatro ultimas la **resolucion** de la
/// pieza; el corte entre las dos es el que separa a las dos referencias.
enum NeuronPhase {
  /// Las lineas guia, que son andamio y llegan primero.
  guides,

  /// El campo de dot matrix.
  dots,

  /// El cumulo de block noise.
  noise,

  /// El ruido condensandose en la forma, y el contenido apareciendo.
  condense,

  /// El pico de aberracion cromatica. Una sola vez.
  chromatic,

  /// Las bandas horizontales desplazadas. Posterior al pico, no simultaneo.
  slice,

  /// La estabilizacion.
  settle,
}

/// Cuanto dura cada fase cuando no se la sobreescribe.
///
/// Las siete suman 850 ms; el revelado de texto, que va sin [NeuronPhase.slice],
/// suma 760.
const neuronPhaseDurations = <NeuronPhase, Duration>{
  NeuronPhase.guides: Duration(milliseconds: 120),
  NeuronPhase.dots: Duration(milliseconds: 100),
  NeuronPhase.noise: Duration(milliseconds: 120),
  NeuronPhase.condense: Duration(milliseconds: 180),
  NeuronPhase.chromatic: Duration(milliseconds: 120),
  NeuronPhase.slice: Duration(milliseconds: 90),
  NeuronPhase.settle: Duration(milliseconds: 120),
};

/// Donde arranca y donde termina una fase dentro del revelado.
typedef NeuronPhaseWindow = ({Duration start, Duration end});

/// Lo que hay que pintar en un instante del revelado.
///
/// Los tres valores de capa son el `progress` de las capas de este package, con
/// **su** polaridad: 0 pinta la capa completa y 1 no pinta nada. Es la inversa a
/// `HoldProgressBorderPainter`, que es el otro painter del repo.
///
/// [content], en cambio, es una opacidad comun: 0 es invisible y 1 es opaco.
typedef NeuronFrame = ({
  NeuronPhase? phase,
  double guides,
  double dots,
  double noise,
  double content,
});
