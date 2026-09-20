part of 'neuron_reveal.dart';

class _NeuronRevealState extends State<NeuronReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);

  late NeuronTimeline _timeline = NeuronTimeline(
    phases: widget.phases,
    durations: widget.durations,
  );

  Timer? _fastPathWindow;
  Timer? _delay;

  /// Si el revelado ya termino, o nunca va a correr.
  bool _done = false;

  /// Si el revelado ya arranco de verdad. Es lo que se avisa por
  /// `onRevealStart`, y lo que evita avisarlo dos veces.
  bool _released = false;

  /// Si la espera del `Stagger` ya se cumplio.
  bool _launched = false;

  /// Si el contenido todavia esta adentro de la ventana de `fastPathAfter`.
  bool _inFastPath = false;

  /// Si el efecto esta habilitado. Arranca en `null` a proposito: con `true` la
  /// primera pasada por `didChangeDependencies` saldria por el `return` temprano
  /// y el revelado no arrancaria nunca.
  bool? _running;

  /// Si el subarbol tiene los tickers prendidos. Una ruta tapada los apaga.
  bool _tickerEnabled = true;

  /// Si el sistema pide «reducir movimiento». Es global, no de este subarbol.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    final fastPathAfter = widget.fastPathAfter;
    if (fastPathAfter == null) return;

    _inFastPath = true;
    // Un `Timer` y no un `Stopwatch`: el reloj del tester es falso y un
    // `Stopwatch` mide el real, asi que en un test la ventana no se cerraria
    // nunca. Los `Timer` si los mueve `tester.pump`.
    _fastPathWindow = Timer(fastPathAfter, () => _inFastPath = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(NeuronReveal oldWidget) {
    super.didUpdateWidget(oldWidget);

    final retimed =
        !listEquals(oldWidget.phases, widget.phases) ||
        !mapEquals(oldWidget.durations, widget.durations);
    if (retimed) {
      _timeline = NeuronTimeline(
        phases: widget.phases,
        durations: widget.durations,
      );
    }

    if (!retimed &&
        oldWidget.ready == widget.ready &&
        oldWidget.alreadyRevealed == widget.alreadyRevealed) {
      return;
    }

    // `force` para saltar el `return` temprano de `_apply`: estos son
    // parametros, no dependencias heredadas, asi que `didChangeDependencies` no
    // se entera de que cambiaron.
    _apply(force: true);
  }

  @override
  void dispose() {
    _fastPathWindow?.cancel();
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // `animateTo` al punto de espera tambien reporta `completed`, con el valor
    // en el medio: lo que termina el revelado es llegar a 1, no el estado.
    if (_controller.value < 1) return;

    setState(_finish);
  }

  @override
  Widget build(BuildContext context) {
    // El arbol final es el hijo solo. Es el tercer remontaje, y el mas barato:
    // pasa cuando el contenido ya es el definitivo.
    if (_done) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _NeuronRevealLayers(
        config: widget,
        timeline: _timeline,
        frame: _timeline.frameAt(_timeline.total * _controller.value),
      ),
    );
  }
}
