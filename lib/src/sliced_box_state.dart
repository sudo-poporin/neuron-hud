part of 'sliced_box.dart';

class _SlicedBoxState extends State<SlicedBox>
    with SingleTickerProviderStateMixin {
  /// Subpasos de una rafaga. En los impares se invierte el corrimiento de todas
  /// las bandas, que es lo que convierte un corrimiento estatico en un temblor.
  static const _stepCount = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.burstDuration,
  )..addStatusListener(_onStatus);

  /// El generador vive en el `State` y no en el widget: se crea una vez y
  /// avanza en cada rafaga, asi que las bandas salen distintas pero la
  /// secuencia es fija para una semilla dada.
  late final math.Random _random = math.Random(widget.seed);

  List<SlicedBand> _slices = const [];
  Timer? _gap;

  /// Si el efecto esta programado. Arranca en `null` a proposito: con `true` la
  /// primera pasada por `didChangeDependencies` saldria por el `return`
  /// temprano y la rafaga no arrancaria nunca.
  bool? _running;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // TickerMode ademas del gate de reduce-motion: en una ruta inactiva
    // Flutter mutea los tickers y un `Timer` no se entera.
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (enabled == _running) return;

    _running = enabled;
    if (enabled) {
      _schedule(initial: true);
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    _gap?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!(_running ?? false)) return;

    _schedule();
  }

  void _schedule({bool initial = false}) {
    final period = widget.period;
    if (period == null) {
      if (initial) _fire();
      return;
    }

    _gap?.cancel();
    _gap = Timer(
      initial ? period * _random.nextDouble() : period * _jitterFactor(),
      _fire,
    );
  }

  double _jitterFactor() {
    final jitter = widget.jitter.clamp(0.0, 1.0);

    return 1 + (_random.nextDouble() * 2 - 1) * jitter;
  }

  void _fire() {
    // Sin guarda de `mounted`: `dispose` cancela el Timer, asi que no hay forma
    // de que esto corra desmontado, y una linea inalcanzable rompe el 100 % de
    // cobertura.
    //
    // Y sin setState: al `forward` le sigue una notificacion del controller, y
    // el AnimatedBuilder reconstruye leyendo `_slices`. Un setState aca
    // reventaria cuando `_fire` sale de didChangeDependencies, que corre en
    // fase de build.
    _slices = _generateSlices();
    _controller
      ..duration = widget.burstDuration
      ..forward(from: 0);
  }

  void _stop() {
    _gap?.cancel();
    _gap = null;
    _slices = const [];
    _controller
      ..stop()
      ..value = 0;
  }

  List<SlicedBand> _generateSlices() {
    final count = math.max(0, widget.sliceCount);

    return [for (var i = 0; i < count; i++) _generateSlice()];
  }

  SlicedBand _generateSlice() {
    final height = 0.04 + _random.nextDouble() * 0.14;

    return (
      // El top se sortea sobre lo que queda, asi que la banda nunca se sale
      // por abajo.
      top: _random.nextDouble() * (1 - height),
      height: height,
      shift: _random.nextDouble() * 2 - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;

        // El `>= 1` no es defensivo: el controller queda parado en 1 al
        // terminar la rafaga, y sin la guarda las bandas se quedarian corridas
        // para siempre.
        //
        // Va como `if` y no como ternario, para que la cobertura vea las dos
        // ramas.
        var slices = const <SlicedBand>[];
        var direction = 1.0;
        if (t > 0 && t < 1) {
          slices = _slices;
          // Tres subpasos, y en los impares se invierte el corrimiento de todas
          // las bandas: es lo que convierte un corrimiento estatico en temblor.
          final step = (t * _stepCount).floor().clamp(0, _stepCount - 1);
          direction = step.isEven ? 1.0 : -1.0;
        }

        return _SlicedBoxLayer(
          slices: slices,
          sliceOffset: widget.sliceOffset,
          direction: direction,
          streaks: widget.streaks,
          streakColor: widget.streakColor,
          streakOverflow: widget.streakOverflow,
          streakStrokeWidth: widget.streakStrokeWidth,
          child: child,
        );
      },
    );
  }
}
