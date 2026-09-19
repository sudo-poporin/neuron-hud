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

  void _apply({bool force = false}) {
    // TickerMode ademas del gate de reduce-motion: en una ruta inactiva Flutter
    // mutea los tickers. `TickerMode.of` esta deprecado desde Flutter 3.35.
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (enabled == _running && !force) return;

    _running = enabled;

    if (_done) return;

    // Ya revelado, sin movimiento, o una lista de fases que no dura nada. Los
    // tres terminan igual y ninguno avisa: no hubo revelado que marcar, y una
    // reconstruccion posterior tampoco lo va a correr.
    if (widget.alreadyRevealed ||
        !enabled ||
        _timeline.total <= Duration.zero) {
      _cancelDelay();
      _finish();

      return;
    }

    // El fast path. **Este si avisa**: es el unico caso donde una reconstruccion
    // posterior —la del `Hero`— si animaria, y el registro es lo que se lo
    // impide.
    if (widget.ready && _inFastPath) {
      _cancelDelay();
      _finish();
      _release();

      return;
    }

    if (!_launched) {
      // La lectura registra la dependencia del scope aunque ya haya un `Timer`
      // esperando, que es lo que hace que un `Stagger` nuevo arriba vuelva a
      // pasar por aca.
      final delay = Stagger.delayOf(context);
      if (delay > Duration.zero) {
        // `??=` y no una asignacion: si ya hay uno esperando se lo deja
        // correr. Reprogramarlo con la duracion entera correria el arranque
        // cada vez que cambia un parametro —un `ready` que llega a mitad de la
        // espera empujaria el turno de esta fila— y el retraso de un
        // escalonado tiene que ser el que le toco, no el ultimo que se pidio.
        //
        // Sin guarda de `mounted`: `dispose` cancela el Timer, asi que no hay
        // forma de que esto corra desmontado.
        _delay ??= Timer(delay, _launch);

        return;
      }

      _cancelDelay();
    }

    _launch();
  }

  void _cancelDelay() {
    _delay?.cancel();
    _delay = null;
  }

  void _launch() {
    _launched = true;
    _controller.duration = _timeline.total;

    // La formacion —guias, puntos, ruido— es el andamio de
    // `hud_inanimation.mp4` y no depende de que el contenido este.
    //
    // Con el punto de espera en 1 no hay ninguna fase de resolucion, asi que
    // `ready` no tiene donde aplicar: la formacion **es** el revelado entero.
    // Frenar ahi dejaria al elemento mostrado —sin `condense` el contenido esta
    // visible desde el primer frame— y a `onRevealStart` sin dispararse nunca,
    // porque el revelado termina en el mismo `animateTo`.
    if (!widget.ready && _timeline.holdPoint < 1) {
      _controller.animateTo(_timeline.holdPoint);

      return;
    }

    _controller.forward();
    _release();
  }

  void _finish() {
    _controller.stop();
    _done = true;
  }

  /// Marca el revelado como arrancado y avisa. Una sola vez.
  ///
  /// **El aviso sale despues del frame, la marca no.** `_apply` corre desde
  /// `didChangeDependencies` y `didUpdateWidget`, o sea en plena fase de build:
  /// un consumidor que haga `setState` en el callback —que es lo natural,
  /// anotar que la fila ya se revelo es cambiar estado— se come el assert de
  /// `setState() called during build`.
  ///
  /// El `_released` se pone igual y sincronico, asi que el aviso sigue siendo
  /// uno solo por revelado aunque lleguen varios rebuilds antes de que el
  /// callback corra.
  ///
  /// El retraso es de un post-frame, no de un frame entero: para un consumidor
  /// que lleve registro de lo revelado, la marca sigue cayendo en el mismo
  /// frame en que el revelado arranca.
  void _release() {
    if (_released) return;

    _released = true;

    final onRevealStart = widget.onRevealStart;
    if (onRevealStart == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onRevealStart();
    });
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
