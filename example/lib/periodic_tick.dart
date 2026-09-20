import 'dart:async';

import 'package:flutter/widgets.dart';

/// Un contador que avanza cada [period], y se apaga con «Reducir movimiento».
///
/// **El package no publica nada así**, y las tres pantallas que muestran algo
/// en bucle lo necesitan:
///
/// - el campo de barras del rol *ausente*, que deriva su layout de una semilla
///   y es `const`: sin alguien que se la cambie, queda fijo;
/// - el revelado, que `NeuronReveal` corre en `initState` y no sabe rebobinar,
///   así que repetirlo es cambiarle la `key` y remontarlo;
/// - el escalonado, por lo mismo.
///
/// Sigue el reparto del resto del sistema: las piezas pintan, y quien las mueve
/// es un widget aparte.
class PeriodicTick extends StatefulWidget {
  const new({required this.period, required this.builder, super.key});

  /// Cada cuánto avanza el contador.
  final Duration period;

  /// Recibe cuántas veces avanzó desde que se montó.
  final Widget Function(BuildContext context, int tick) builder;

  @override
  State<PeriodicTick> createState() => _PeriodicTickState();
}

class _PeriodicTickState extends State<PeriodicTick> {
  Timer? _timer;

  int _tick = 0;

  /// Si el reloj está corriendo. Arranca en `null` para que la primera pasada
  /// por `didChangeDependencies` no salga por el `return` temprano.
  bool? _running;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(PeriodicTick oldWidget) {
    super.didUpdateWidget(oldWidget);

    // El período es un parámetro y no una dependencia heredada, así que
    // `_apply` no se entera solo: sin esto, cambiarlo en vivo no reprograma
    // nada.
    if (oldWidget.period != widget.period) _apply(force: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _tick);

  void _apply({bool force = false}) {
    // En una ruta inactiva Flutter mutea los tickers, y no hay motivo para que
    // un `Timer` siga gastando ahí. Y con «Reducir movimiento» el contador
    // queda en cero: nada se repite y no se crea ni un timer.
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    if (enabled == _running && !force) return;

    _running = enabled;
    _timer?.cancel();
    _timer = null;

    if (!enabled) return;

    // Sin guarda de `mounted`: `dispose` cancela el Timer.
    _timer = Timer.periodic(widget.period, (_) => setState(() => _tick++));
  }
}
