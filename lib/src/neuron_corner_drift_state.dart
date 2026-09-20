part of 'neuron_corner_drift.dart';

/// Hacia donde entra cada esquina cuando se mueve hacia el centro.
///
/// En el orden de `TechFrame.cornerOffsets`. La superior izquierda entra hacia
/// la derecha y hacia abajo; la inferior derecha, al reves.
const _inwards = <Offset>[
  Offset(1, 1),
  Offset(-1, 1),
  Offset(1, -1),
  Offset(-1, -1),
];

class _NeuronCornerDriftState extends State<NeuronCornerDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  /// Si las esquinas se estan moviendo. Arranca en `null` a proposito: con
  /// `true` la primera pasada por `didChangeDependencies` saldria por el
  /// `return` temprano y no arrancarian nunca.
  bool? _drifting;

  static const _quietas = <Offset>[
    Offset.zero,
    Offset.zero,
    Offset.zero,
    Offset.zero,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(NeuronCornerDrift oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.period == widget.period &&
        oldWidget.amplitude == widget.amplitude) {
      return;
    }

    // `force` para saltar el `return` temprano de `_apply`: el periodo y la
    // amplitud son parametros, no dependencias heredadas.
    _controller.duration = widget.period;
    _apply(force: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply({bool force = false}) {
    final enabled =
        widget.amplitude != 0 &&
        widget.period > Duration.zero &&
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    if (enabled == _drifting && !force) return;

    _drifting = enabled;

    if (enabled) {
      _controller.repeat();
      return;
    }

    _controller
      ..stop()
      ..value = 0;
  }

  /// La fase de la esquina [index]: un cuarto de ciclo entre vecinas.
  double _phase(int index) => index / 4 + (widget.seed % 4) / 16;

  List<Offset> _corners() {
    if (!(_drifting ?? false)) return _quietas;

    return List<Offset>.generate(4, (index) {
      final turn = (_controller.value + _phase(index)) * 2 * math.pi;

      // Sobre la diagonal: un solo seno para los dos ejes, con el signo que
      // apunta al centro. Nunca sale hacia afuera de la caja.
      final inset =
          _inwards[index] * ((math.sin(turn) + 1) / 2) * widget.amplitude;

      // Los dos ejes por separado, desfasados un cuarto de vuelta entre si:
      // eso es una elipse y no una diagonal.
      final free = Offset(
        math.sin(turn) * widget.amplitude,
        math.cos(turn) * widget.amplitude,
      );

      return switch (widget.mode) {
        NeuronCornerDriftMode.inset => inset,
        NeuronCornerDriftMode.free => free,
        NeuronCornerDriftMode.combined => inset + free,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _corners()),
    );
  }
}
