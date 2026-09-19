part of 'neuron_reveal.dart';

/// Las capas del revelado para un frame dado.
///
/// Es lo que antes componia `_NeuronRevealState._compose`. Salio del `State`
/// porque `AGENTS.md` prohibe los helper methods que devuelven widgets: no
/// pueden ser `const` ni tener ciclo de vida propio.
///
/// **Recibe el widget entero como [config], no sus campos sueltos.** La
/// alternativa son ocho parametros —`ink`, `seed`, `chromaticA`, `chromaticB`,
/// `chromaticOffset`, `child`, mas [timeline] y [frame]— que habria que
/// mantener sincronizados a mano cada vez que [NeuronReveal] gana un campo.
///
/// **No ahorra reconstrucciones y no pretende hacerlo.** Los tres parametros
/// cambian en cada frame, asi que esto se reconstruye igual que antes se
/// reevaluaba el metodo.
class _NeuronRevealLayers extends StatelessWidget {
  const new({
    required this.config,
    required this.timeline,
    required this.frame,
  });

  /// El [NeuronReveal] que se esta revelando: de ahi salen la tinta, la
  /// semilla, los dos colores cromaticos, el desfase y el hijo.
  final NeuronReveal config;

  /// El reparto de fases en el tiempo, ya resuelto por el `State`.
  final NeuronTimeline timeline;

  /// El estado de las capas en este frame.
  final NeuronFrame frame;

  @override
  Widget build(BuildContext context) {
    // No se saca cuando llega a 1: sacarlo cambiaria el widget que esta arriba
    // del contenido y lo remontaria, justo en el borde de `condense`.
    //
    // Y **no es un `Opacity`**, aunque haga lo mismo. `RenderOpacity` declara
    // `alwaysNeedsCompositing => child != null && _alpha > 0`, o sea que compone
    // con **cualquier** alpha que no sea cero, 255 incluido. Eso lo vuelve
    // repaint boundary todo el revelado, y un repaint boundary abajo de los
    // burst rompe las dos cosas que hacen: `ChromaticBurst` no puede repintar al
    // hijo para los fantasmas —`PaintingContext.appendLayer` arranca con
    // `layer.remove()`, asi que la segunda pasada le roba la capa a la
    // primera— y su `saveLayer` cae sobre una capa vacia, que degradaba el blend
    // a `srcOver` mucho antes de que existieran los render objects.
    Widget content = _ContentOpacity(
      opacity: frame.content,
      child: config.child,
    );

    // El anidado es el 統合 del diagrama: los puntos al fondo, el ruido encima,
    // las guias arriba. Las tres se quedan puestas todo el revelado aunque su
    // `progress` este en 1 y no pinten: sacarlas seria un remontaje mas por
    // capa, y un `CustomPaint` que no dibuja no cuesta nada.
    content = DotMatrix(
      color: config.ink.withValues(alpha: 0.2),
      progress: frame.dots,
      child: content,
    );
    content = BlockNoise(
      color: config.ink,
      progress: frame.noise,
      seed: config.seed,
      child: content,
    );
    content = GuideLines(
      color: config.ink.withValues(alpha: 0.4),
      progress: frame.guides,
      seed: config.seed,
      child: content,
    );

    if (_burstIsMounted(frame.phase, NeuronPhase.slice)) {
      content = SlicedBox(
        period: null,
        burstDuration: timeline.durationOf(NeuronPhase.slice),
        seed: config.seed,
        child: content,
      );
    }

    if (_burstIsMounted(frame.phase, NeuronPhase.chromatic)) {
      content = ChromaticBurst(
        period: null,
        burstDuration: timeline.durationOf(NeuronPhase.chromatic),
        colorA: config.chromaticA,
        colorB: config.chromaticB,
        offset: config.chromaticOffset,
        seed: config.seed,
        child: content,
      );
    }

    return content;
  }

  /// Si el efecto de [phase] tiene que estar montado en [current].
  ///
  /// Se monta al entrar en su fase —montarlo es lo que dispara su tiro unico— y
  /// se queda hasta el final: desmontarlo costaria un remontaje mas del hijo y
  /// no compraria nada, porque con su controller en 1 devuelve el hijo pelado.
  ///
  /// **Con el contenido todavia ausente no se monta ninguno.** El punto de
  /// espera es el arranque de la primera fase de resolucion presente, asi que
  /// una lista de fases sin `condense` lo deja justo en `chromatic`: el
  /// revelado se para ahi, pero la fase activa ya es esa y la rafaga se
  /// montaria igual. Como dispara al montarse y una sola vez, el pico se
  /// gastaria contra un hijo oculto y no quedaria nada para cuando el contenido
  /// llegue. Con `condense` presente no pasa —la espera cae antes—, que es por
  /// lo que no se veia con las fases por default.
  bool _burstIsMounted(NeuronPhase? current, NeuronPhase phase) =>
      config.ready &&
      timeline.contains(phase) &&
      current != null &&
      current.index >= phase.index;
}
