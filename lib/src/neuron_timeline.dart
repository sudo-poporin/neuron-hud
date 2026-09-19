part 'neuron_phase.dart';

/// La linea de tiempo de un revelado: que fases corren, cuando, y que se pinta
/// en cada instante.
///
/// No es un widget y no tiene reloj: recibe el instante y devuelve el
/// [NeuronFrame]. Quien lo mueve es `NeuronReveal`.
class NeuronTimeline {
  /// La linea de tiempo de un revelado.
  ///
  /// [phases] dice **cuales** fases corren, no en que orden: el orden es siempre
  /// el de [NeuronPhase.values]. Asi una lista desordenada no arma una secuencia
  /// sin sentido y una repetida no duplica la fase.
  ///
  /// [durations] es un override **parcial**: se lee por fase sobre
  /// [neuronPhaseDurations], asi que una sola entrada cambia una sola fase. Una
  /// fase que no esta en [phases] no aporta duracion, este o no en el mapa.
  factory({
    required List<NeuronPhase> phases,
    Map<NeuronPhase, Duration>? durations,
  }) {
    final windows = <NeuronPhase, NeuronPhaseWindow>{};
    var cursor = Duration.zero;

    for (final phase in NeuronPhase.values) {
      if (!phases.contains(phase)) continue;

      final duration = durations?[phase] ?? neuronPhaseDurations[phase]!;
      // Una duracion negativa correria las ventanas para atras: se toma como
      // cero, que es lo mismo que pedir que la fase no dure.
      final end = cursor + (duration.isNegative ? Duration.zero : duration);

      windows[phase] = (start: cursor, end: end);
      cursor = end;
    }

    return NeuronTimeline._(windows, cursor);
  }

  new _(this._windows, this.total);

  /// Las fases de resolucion, en orden. De aca en adelante hace falta que el
  /// contenido este.
  static const List<NeuronPhase> _resolution = [
    NeuronPhase.condense,
    NeuronPhase.chromatic,
    NeuronPhase.slice,
    NeuronPhase.settle,
  ];

  final Map<NeuronPhase, NeuronPhaseWindow> _windows;

  /// Cuanto dura el revelado entero.
  final Duration total;

  /// Donde se para el revelado mientras el contenido no esta, de 0 a 1.
  ///
  /// Es el arranque de la primera fase de resolucion presente. Las anteriores
  /// —guias, puntos, ruido— son la formacion del esqueleto y corren sin esperar
  /// a nadie. Sin ninguna fase de resolucion, la espera cae al final.
  double get holdPoint {
    if (total <= Duration.zero) return 1;

    for (final phase in _resolution) {
      final window = _windows[phase];
      if (window != null) {
        return window.start.inMicroseconds / total.inMicroseconds;
      }
    }

    return 1;
  }

  /// Si la fase corre en este revelado.
  bool contains(NeuronPhase phase) => _windows.containsKey(phase);

  /// Cuanto dura una fase, o `Duration.zero` si no corre.
  Duration durationOf(NeuronPhase phase) {
    final window = _windows[phase];
    if (window == null) return Duration.zero;

    return window.end - window.start;
  }

  /// Que se pinta en [elapsed].
  NeuronFrame frameAt(Duration elapsed) => (
    phase: _phaseAt(elapsed),
    guides: _layer(elapsed, NeuronPhase.guides, NeuronPhase.settle),
    dots: _layer(elapsed, NeuronPhase.dots, NeuronPhase.condense),
    noise: _layer(elapsed, NeuronPhase.noise, NeuronPhase.condense),
    content: _content(elapsed),
  );

  NeuronPhase? _phaseAt(Duration elapsed) {
    // El mapa se llena en el orden del enum, asi que recorrerlo es recorrer la
    // secuencia.
    for (final entry in _windows.entries) {
      if (elapsed >= entry.value.start && elapsed < entry.value.end) {
        return entry.key;
      }
    }

    return null;
  }

  double _layer(Duration elapsed, NeuronPhase fadeIn, NeuronPhase fadeOut) {
    final entrada = _windows[fadeIn];
    // Sin su fase de entrada, la capa no se pinta nunca.
    if (entrada == null) return 1;
    if (elapsed < entrada.start) return 1;
    // Entra llevando su `progress` de 1 a 0.
    if (elapsed < entrada.end) return 1 - _fraction(elapsed, entrada);

    final salida = _windows[fadeOut];
    // Sin su fase de salida, la capa vive hasta el final del revelado.
    if (salida == null || elapsed < salida.start) return 0;
    // Y sale llevandolo de 0 a 1.
    if (elapsed < salida.end) return _fraction(elapsed, salida);

    return 1;
  }

  double _content(Duration elapsed) {
    final condense = _windows[NeuronPhase.condense];
    // Sin `condense` no hay de que condensarlo: el contenido esta visible desde
    // el primer frame.
    if (condense == null) return 1;
    if (elapsed < condense.start) return 0;
    if (elapsed < condense.end) return _fraction(elapsed, condense);

    return 1;
  }

  /// Cuanto avanzo [elapsed] adentro de [window], de 0 a 1.
  ///
  /// Sin guarda de ventana vacia: los dos llamadores entran solo cuando
  /// `start <= elapsed < end`, que ya implica que la ventana dura algo.
  double _fraction(Duration elapsed, NeuronPhaseWindow window) =>
      (elapsed.inMicroseconds - window.start.inMicroseconds) /
      (window.end.inMicroseconds - window.start.inMicroseconds);
}
