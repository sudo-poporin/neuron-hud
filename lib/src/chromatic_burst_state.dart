part of 'chromatic_burst.dart';

class _ChromaticBurstState extends State<ChromaticBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.burstDuration,
  )..addStatusListener(_onStatus);

  /// El generador vive en el `State` y no en el widget: se crea una vez y
  /// avanza en cada rafaga, asi que las pausas salen distintas pero la
  /// secuencia es fija para una semilla dada. Un `Random` como campo del widget
  /// impediria el constructor `const`.
  late final math.Random _random = math.Random(widget.seed);

  /// El generador de la inclinacion, **deliberadamente sin semilla**.
  ///
  /// Es el unico azar del widget que no sale de [ChromaticBurst.seed], y la
  /// razon es que la inclinacion tiene que cambiar **en cada aparicion**. En el
  /// modo de disparo unico —el que usa `NeuronReveal` en su fase `chromatic`,
  /// o sea todas las portadas de la app— hay un solo destello por montaje: con
  /// el generador sembrado, la misma portada se glitcheaba siempre con el mismo
  /// angulo y el mismo color de cada lado, scroll tras scroll.
  ///
  /// **El precio es que la inclinacion no es reproducible**, asi que un test no
  /// puede aseverar su valor: solo que cae dentro del maximo, que cambia entre
  /// rafagas y que los dos lados aparecen. Todo lo demas —la pausa, el jitter,
  /// la fase inicial— sigue saliendo de la semilla y sigue siendo determinista.
  ///
  /// Con `maxTilt` en 0 este generador no se toca, asi que el modo referencia
  /// sigue siendo exacto y es el que usan los tests que miden un pixel.
  final math.Random _tiltRandom = math.Random();

  /// Inclinacion del eje del desfase de la rafaga en curso, en radianes.
  ///
  /// Se sortea en cada `_fire` con el mismo generador que la pausa, asi que la
  /// secuencia es fija para una semilla dada y los tests son deterministas.
  double _tilt = 0;

  Timer? _gap;

  /// Si el efecto esta programado. Arranca en `null` a proposito: con `true` la
  /// primera pasada por `didChangeDependencies` saldria por el `return`
  /// temprano y la rafaga no arrancaria nunca.
  bool? _running;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // TickerMode ademas del gate de reduce-motion: en una ruta inactiva
    // —una pantalla que quedo abajo de un push— Flutter mutea los tickers, y
    // un `Timer` no se entera. Sin esto, veinte cajas de una lista que ya no
    // se ve siguen despertandose a programar rafagas que no tickean.
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
      // Disparo unico: sin fase inicial y sin reprogramacion.
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
    // La duracion se relee en cada rafaga en vez de en initState, asi cambiar
    // burstDuration en vivo tiene efecto sin un didUpdateWidget.
    //
    // Y el angulo se sortea aca y no en el build: el build corre en cada frame
    // de la rafaga, y un angulo nuevo por frame haria vibrar el eje en vez de
    // inclinarlo.
    _tilt = _tiltForBurst();
    _controller
      ..duration = widget.burstDuration
      ..forward(from: 0);
  }

  /// La direccion del eje del desfase de esta rafaga, en radianes.
  ///
  /// Un angulo al azar entre `-maxTilt` y `+maxTilt`, y media vuelta mas la
  /// mitad de las veces —que es lo que intercambia de lado los dos colores—.
  double _tiltForBurst() {
    // Con el maximo en 0 no queda nada que sortear: ni inclinacion ni
    // intercambio. Es el modo referencia, y sin esta guarda el intercambio
    // seguiria ocurriendo con el eje horizontal.
    if (widget.maxTilt == 0) return 0;

    final degrees = (_tiltRandom.nextDouble() * 2 - 1) * widget.maxTilt;
    final flipped = _tiltRandom.nextBool();

    return (degrees + (flipped ? 180 : 0)) * math.pi / 180;
  }

  void _stop() {
    _gap?.cancel();
    _gap = null;
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;

        // La guarda cubre los dos extremos y los dos hacen falta: en 0 esta el
        // reposo de antes de la primera rafaga, y en 1 el de despues de cada
        // una — el controller queda parado ahi. Ademas `sin(pi)` no da
        // exactamente 0.
        //
        // Va como `if` y no como ternario: un ternario es una sola linea y
        // daria 100 % de cobertura con una de las dos ramas sin ejercitar.
        var amount = 0.0;
        if (t > 0 && t < 1) {
          // sin(t*pi): el desfase va 0 -> offset -> 0, con el maximo en la
          // mitad de la rafaga. Es el PICO de la referencia, no una rampa.
          amount = math.sin(t * math.pi);
        }

        return _ChromaticBurstLayer(
          amount: amount,
          offset: widget.offset,
          tilt: _tilt,
          colorA: widget.colorA,
          colorB: widget.colorB,
          blendMode: widget.blendMode,
          child: child,
        );
      },
    );
  }
}
