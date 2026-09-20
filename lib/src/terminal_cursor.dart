import 'dart:async';

import 'package:flutter/widgets.dart';

/// Un glifo que parpadea al final del contenido, como el cursor de una
/// terminal.
///
/// Sale de los headers `MAP_`, `ITEM_` y `LEGION_` de `menu_noize.mp4`, el
/// video del blog oficial de PlatinumGames en
/// https://www.platinumgames.com/official-blog/article/10397, donde el guion
/// bajo del final parpadea con un ciclo de 150-250 ms.
///
/// Es el mas barato de los efectos del set: un `Timer` que alterna un
/// `Opacity`, sin `AnimationController` y sin un vsync por frame.
///
/// **El ancho no cambia entre glifo prendido y apagado.** El `Text` del glifo
/// siempre se layoutea y lo que alterna es un `Opacity` encima, que no pinta
/// pero mide igual. Si no, el label saltaria cada 100 ms.
///
/// **Con «Reducir movimiento» prendido el glifo queda visible y fijo**, y no se
/// crea ningun `Timer`.
///
/// Es el unico widget de este package que necesita un `Directionality`
/// ancestro: usa un `Row`, y el glifo va del lado del final del texto. En la app
/// lo pone `WidgetsApp`; en un test hay que envolverlo.
class TerminalCursor extends StatefulWidget {
  /// Un glifo que parpadea al final del contenido.
  const new({
    required this.child,
    super.key,
    this.glyph = '_',
    this.period = const Duration(milliseconds: 200),
    this.style,
    this.gap = 2,
  });

  /// Contenido al que se le agrega el cursor.
  ///
  /// Va adentro de un `Flexible` propio, asi que un texto largo wrappea en vez
  /// de desbordar. Sin eso, el `Row` de abajo le da restricciones de ancho no
  /// acotadas y un label que no entra revienta la fila —medido: 847 px de
  /// desborde en una caja de 72—. El `Flexible` lo pone este widget y no su
  /// consumidor porque el `Row` es suyo: pasarle uno desde afuera funciona hoy
  /// pero se rompe apenas alguien mete un `Padding` en el medio.
  final Widget child;

  /// El glifo que parpadea.
  final String glyph;

  /// Duracion del **ciclo completo**: prendido mas apagado.
  ///
  /// El default de 200 ms son cinco parpadeos por segundo, que es el ciclo de
  /// 150-250 ms de la referencia. Cruza el umbral de tres flashes por segundo
  /// de WCAG 2.3.1, y es deliberado: el area es un glifo de unos 8 px, y con
  /// «Reducir movimiento» prendido el parpadeo no existe.
  ///
  /// Con `Duration.zero` —o con cualquier valor cuya mitad redondee a cero,
  /// como un microsegundo— no se crea ningun `Timer` y el glifo queda visible.
  /// Cambiarlo en vivo en cualquiera de los dos sentidos funciona.
  final Duration period;

  /// Estilo del glifo.
  ///
  /// Con `null` hereda el `DefaultTextStyle` del entorno, que es como este
  /// package se entera de la tipografia de su consumidor sin importar nada
  /// suyo.
  final TextStyle? style;

  /// Espacio entre el contenido y el glifo.
  final double gap;

  @override
  State<TerminalCursor> createState() => _TerminalCursorState();
}

class _TerminalCursorState extends State<TerminalCursor> {
  Timer? _timer;
  bool _visible = true;

  /// Si el parpadeo esta habilitado. Arranca en `null` a proposito: con `true`
  /// la primera pasada por `didChangeDependencies` saldria por el `return`
  /// temprano y el cursor no parpadearia nunca.
  bool? _blinking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(TerminalCursor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // `Timer.periodic` captura su duracion al crearse, asi que un periodo
    // nuevo no tiene efecto sin recrearlo. Y va por `_apply` y no por `_start`
    // porque el gate depende del periodo: `didChangeDependencies` solo vuelve
    // a correr cuando cambia una dependencia heredada, asi que sin `force`
    // pasar a `Duration.zero` en vivo dejaria un `Timer.periodic(Duration.zero)`
    // girando, y el camino inverso dejaria el cursor muerto para siempre.
    if (oldWidget.period == widget.period) return;
    _apply(force: true);
  }

  /// Arranca o para el parpadeo segun el gate de reduce-motion y el periodo.
  ///
  /// Con [force] se salta el `return` temprano, para cuando lo que cambio es el
  /// periodo y no el gate.
  void _apply({bool force = false}) {
    // maybeDisableAnimationsOf y no disableAnimationsOf: la segunda lanza si
    // no hay un MediaQuery ancestro, y este package no puede exigir uno.
    //
    // El gate mira el periodo **ya dividido**, que es lo que recibe el Timer:
    // un `Duration(microseconds: 1)` es mayor que cero pero su mitad no, y un
    // `Timer.periodic(Duration.zero)` gira en cada turno del event loop.
    // TickerMode primero: en una ruta inactiva Flutter mutea los tickers, y un
    // `Timer` no se entera — este widget no usa ticker, asi que sin esto sigue
    // llamando setState en una pantalla que ya no se ve.
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        widget.period ~/ 2 > Duration.zero;
    if (!force && enabled == _blinking) return;

    _blinking = enabled;
    if (enabled) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      widget.period ~/ 2,
      (_) => setState(() => _visible = !_visible),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    // Sin setState: a `_apply` le sigue siempre un build, porque sus dos
    // llamadores —didChangeDependencies y didUpdateWidget— corren en fase de
    // build. Un setState aca reventaria.
    _visible = true;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      // El glifo se apoya en la linea base del texto, no en el centro de la
      // caja.
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: widget.child),
        SizedBox(width: widget.gap),
        // El glifo es decoracion: sin esto un lector de pantalla lo anuncia
        // como parte del contenido —«Agregando... guion bajo»— porque el
        // subarbol de un boton se anuncia entero.
        ExcludeSemantics(
          child: Opacity(
            opacity: _visible ? 1 : 0,
            child: Text(widget.glyph, style: widget.style),
          ),
        ),
      ],
    );
  }
}
