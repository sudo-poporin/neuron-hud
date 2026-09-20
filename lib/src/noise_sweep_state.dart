part of 'noise_sweep.dart';

class _NoiseSweepState extends State<NoiseSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  /// Si el barrido esta corriendo. Arranca en `null` a proposito: con `true` la
  /// primera pasada por `didChangeDependencies` saldria por el `return`
  /// temprano y el barrido no arrancaria nunca.
  bool? _sweeping;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(NoiseSweep oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.period == widget.period) return;

    // `force` porque el gate depende del periodo, y `didChangeDependencies`
    // solo vuelve a correr cuando cambia una dependencia heredada. Sin esto,
    // pasar de un periodo valido a `Duration.zero` en vivo revienta con
    // `_periodInSeconds > 0.0': is not true`, y el camino inverso deja el
    // barrido muerto para siempre.
    _controller.duration = widget.period;
    _apply(force: true);
  }

  /// Arranca o para el barrido segun el gate de reduce-motion y el periodo.
  ///
  /// Con [force] se salta el `return` temprano, para cuando lo que cambio es el
  /// periodo y no el gate.
  void _apply({bool force = false}) {
    // TickerMode ademas del gate de reduce-motion: en una ruta inactiva
    // Flutter mutea los tickers, y con esto el controller ni arranca.
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        widget.period > Duration.zero;
    if (!force && enabled == _sweeping) return;

    _sweeping = enabled;
    if (enabled) {
      // `repeat()` arranca desde el valor actual, asi que reanudar despues de
      // un parkeo en 0,5 sigue desde ahi y wrapea a 0 en la mitad de la
      // primera vuelta. Es correcto: el barrido es ciclico y no tiene un
      // arranque privilegiado.
      _controller.repeat();
    } else {
      // El estado quieto es el medio del recorrido, no el arranque: en 0 la
      // banda esta afuera de la caja y no se veria nada.
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => CustomPaint(
        foregroundPainter: NoiseSweepPainter(
          t: _controller.value,
          mode: widget.mode,
          color: widget.color,
          bandWidth: widget.bandWidth,
          trail: widget.trail,
          direction: widget.direction,
          wispCount: widget.wispCount,
          seed: widget.seed,
        ),
        child: child,
      ),
    );
  }
}
