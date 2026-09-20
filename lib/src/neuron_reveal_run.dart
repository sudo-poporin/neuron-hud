part of 'neuron_reveal.dart';

/// El control de la corrida del revelado: cuando arranca, cuando espera y
/// cuando avisa.
///
/// Vive aparte del `State` porque es la mitad que decide, y la otra mitad es
/// el ciclo de vida del widget mas el `build`. `_onStatus` se queda alla: es
/// lo unico que llama `setState`.
extension _NeuronRevealRun on _NeuronRevealState {
  void _apply({bool force = false}) {
    // TickerMode ademas del gate de reduce-motion: en una ruta inactiva Flutter
    // mutea los tickers. `TickerMode.of` esta deprecado desde Flutter 3.35.
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final enabled = _tickerEnabled && !_reduceMotion;
    if (enabled == _running && !force) return;

    _running = enabled;

    if (_done) return;

    // Ya revelado, sin movimiento, o una lista de fases que no dura nada. Los
    // tres terminan igual y ninguno avisa: no hubo revelado que marcar, y una
    // reconstruccion posterior tampoco lo va a correr.
    // **`alreadyRevealed` sólo corta si llega antes de arrancar.** El ciclo
    // natural de un consumidor es persistir la marca cuando le avisan y
    // devolverla como prop en el rebuild siguiente; sin el `!_released`, ese
    // rebuild mata la secuencia que el aviso acababa de anunciar y el contenido
    // salta a resuelto a mitad de camino.
    if ((widget.alreadyRevealed && !_released) ||
        _reduceMotion ||
        _timeline.total <= Duration.zero) {
      _cancelDelay();
      _finish();

      return;
    }

    // Una ruta inactiva termina igual —el contenido se muestra resuelto— pero
    // **si avisa**, que es lo que la separa de los tres de arriba.
    //
    // «Reducir movimiento» es global: la copia que arma un `Hero` al volar
    // tampoco se anima, asi que no hay nada que callar. Una ruta inactiva es de
    // este subarbol y transitoria: sin el aviso, el consumidor nunca registra
    // el revelado y esa copia se revela de nuevo, que es justo el rebote que el
    // registro existe para callar.
    if (!_tickerEnabled) {
      _cancelDelay();
      _release();
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
}
