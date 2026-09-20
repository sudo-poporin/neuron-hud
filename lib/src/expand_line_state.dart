part of 'expand_line.dart';

class _ExpandLineState extends State<ExpandLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  Timer? _delay;

  /// Si el efecto esta habilitado. Arranca en `null` a proposito: con `true` la
  /// primera pasada por `didChangeDependencies` saldria por el `return` temprano
  /// y la apertura no arrancaria nunca.
  bool? _running;

  Duration get _total => widget.lineHold + widget.duration;

  /// El alto de la linea, recortado a positivo.
  ///
  /// Un valor negativo llega hasta `BoxConstraints`, que **lanza** en el layout
  /// con un `minHeight` menor que cero. El painter ya lo trata como una linea
  /// vacia, asi que recortarlo a 0 no cambia lo que se ve: deja al panel
  /// arrancando sin alto en vez de reventando.
  double get _lineHeight => widget.lineHeight < 0 ? 0 : widget.lineHeight;

  /// Que fraccion del recorrido se va en la pausa de la linea.
  ///
  /// Recortada a `0..1`, igual que las duraciones negativas de la linea de
  /// tiempo del orquestador: un `lineHold` negativo contra una `duration`
  /// positiva deja `_total` positivo, asi que la guarda de abajo no lo agarra, y
  /// sin recorte el panel arrancaria medio abierto y sin linea.
  double get _holdFraction => _total <= Duration.zero
      ? 1
      : (widget.lineHold.inMicroseconds / _total.inMicroseconds).clamp(
          0.0,
          1.0,
        );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(ExpandLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration == widget.duration &&
        oldWidget.lineHold == widget.lineHold) {
      return;
    }

    // `force` para saltar el `return` temprano de `_apply`: las duraciones son
    // parametros, no dependencias heredadas, asi que `didChangeDependencies` no
    // se entera de que cambiaron.
    _apply(force: true);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _apply({bool force = false}) {
    // TickerMode ademas del gate de reduce-motion: en una ruta inactiva Flutter
    // mutea los tickers, y un `Timer` no se entera. `TickerMode.of` esta
    // deprecado desde Flutter 3.35.
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (enabled == _running && !force) return;

    _running = enabled;
    _delay?.cancel();
    _delay = null;

    // El panel abierto y sin linea, que es como queda al final del segundo
    // tramo.
    if (!enabled || _total <= Duration.zero) {
      _controller
        ..stop()
        ..value = 1;

      return;
    }

    _controller.duration = _total;

    final delay = Stagger.delayOf(context);
    if (delay <= Duration.zero) {
      _controller.forward(from: 0);

      return;
    }

    _controller.value = 0;
    // Sin guarda de `mounted`: `dispose` cancela el Timer, asi que no hay forma
    // de que esto corra desmontado, y una linea inalcanzable rompe el 100 % de
    // cobertura.
    _delay = Timer(delay, () => _controller.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final hold = _holdFraction;
        // Con la fraccion en 1 no queda recorrido para crecer, y hay dos
        // maneras de llegar ahi que piden cosas distintas. Con `_total` en cero
        // —las dos duraciones en cero, la forma soportada de desactivar el
        // efecto— el controller ya esta en 1 y el panel tiene que estar
        // abierto. Con `duration` en cero y `lineHold` positivo hay recorrido:
        // es todo pausa, y la linea tiene que sostenerse sola hasta el final y
        // recien ahi abrirse de golpe. Devolver 1 en los dos casos abria el
        // panel desde el primer frame y se comia la pausa entera.
        final growth = hold >= 1
            ? (_controller.value >= 1 ? 1.0 : 0.0)
            : ((_controller.value - hold) / (1 - hold)).clamp(0.0, 1.0);
        // El clamp no es defensivo de mas: una curva con rebote —easeOutBack,
        // elasticIn— devuelve valores fuera de 0..1, y `Align.heightFactor`
        // afirma que no son negativos.
        final factor = widget.curve.transform(growth).clamp(0.0, 1.0);

        return ConstrainedBox(
          // El `Align` con `heightFactor` en 0 mide cero de alto: este piso es
          // lo que deja la linea sola visible durante `lineHold`.
          constraints: BoxConstraints(minHeight: _lineHeight),
          child: CustomPaint(
            // `foregroundPainter` y no `painter`: el primero resuelve el hit
            // test con `?? false` y no absorbe los taps, el segundo con
            // `?? true` si — y se comeria cada tap del panel.
            foregroundPainter: ExpandLinePainter(
              color: widget.lineColor,
              lineHeight: _lineHeight,
              alignment: widget.alignment,
              opacity: 1 - factor,
            ),
            child: ClipRect(
              // `Align` no clipea: sin el `ClipRect` el hijo se pintaria entero
              // desde el primer frame y el efecto no existiria.
              child: Align(
                alignment: widget.alignment,
                // `widthFactor` en 1 y no en null: con null, `Align` se estira
                // a lo ancho de las constraints que reciba, asi que un panel
                // que hoy se ajusta a su contenido pasaria a ocupar todo el
                // ancho disponible con solo envolverlo. Este widget toca el
                // alto y nada mas.
                widthFactor: 1,
                heightFactor: factor,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
