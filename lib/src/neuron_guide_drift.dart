import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Cuanto derivan las guias hacia cada lado, en pixeles logicos.
///
/// Cuatro. Se eligio comparando cero, dos, cuatro y ocho en el dispositivo, con
/// la misma semilla y el mismo periodo en las cuatro filas para que lo unico que
/// cambiara fuera la amplitud. Con dos el movimiento existe pero no se lee; con
/// ocho las guias dejan de ser andamio y se convierten en el elemento que mas
/// llama la atencion de la caja.
const neuronGuideDriftAmplitude = 4.0;

/// Cada cuanto las guias completan una ida y vuelta, desfasado por la semilla.
///
/// Entre 3,2 y 4,4 segundos: es un orden de magnitud mas lento que el ruido
/// —que cambia entre cinco y once veces por segundo— y el doble de lento que el
/// barrido. Tiene que serlo: las guias son andamio, y andamio que se mueve
/// rapido deja de leerse como referencia y pasa a competir con el contenido.
///
/// El desfase es por el mismo motivo que el de los otros dos relojes del
/// esqueleto: veinte cajas montadas en el mismo frame y con el mismo periodo se
/// mueven todas juntas, y eso lee como si la pantalla entera temblara en vez de
/// como veinte elementos esperando cada uno por su cuenta.
///
/// El `%` de Dart sobre enteros devuelve siempre un valor no negativo.
Duration neuronGuideDriftPeriod(int seed) =>
    Duration(milliseconds: 3200 + (seed % 6) * 240);

/// Mueve las guias de un lado a otro, apenas, mientras el elemento no resuelva.
///
/// **El reparto es el de siempre en este sistema**: las capas son
/// `StatelessWidget` sin reloj —derivan su layout de sus parametros y no se
/// mueven solas—, asi que quien las mueve es un widget aparte, como este.
///
/// **Corre la posicion y no la semilla.** Reseedear reparte las lineas en otro
/// lado de la caja y eso lee como un salto, que es lo que el propio
/// `NeuronSkeleton` descartaba cuando decia que las guias se quedan donde
/// estan. Un desplazamiento de unos pocos pixeles no las reparte: las deja
/// donde estaban, apenas moviendose.
///
/// La onda es un seno y no una rampa: una rampa las corre siempre para el mismo
/// lado y tiene que volver de un salto al terminar el ciclo, que es
/// exactamente el defecto que esto evita.
///
/// **Con «Reducir movimiento» prendido el controller ni arranca** y el builder
/// recibe cero, que son las guias quietas de siempre.
class NeuronGuideDrift extends StatefulWidget {
  /// Mueve las guias de un lado a otro mientras el elemento no resuelva.
  const new({
    required this.amplitude,
    required this.period,
    required this.builder,
    super.key,
  });

  /// Cuanto se corren las guias hacia cada lado, en pixeles logicos.
  ///
  /// En cero el builder recibe siempre cero y no se crea ningun controller.
  final double amplitude;

  /// Cuanto dura una ida y vuelta completa.
  final Duration period;

  /// Construye el subarbol con el desplazamiento del instante.
  final Widget Function(BuildContext context, double drift) builder;

  @override
  State<NeuronGuideDrift> createState() => _NeuronGuideDriftState();
}

class _NeuronGuideDriftState extends State<NeuronGuideDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  /// Si las guias estan derivando. Arranca en `null` a proposito: con `true` la
  /// primera pasada por `didChangeDependencies` saldria por el `return`
  /// temprano y la deriva no arrancaria nunca.
  bool? _drifting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didUpdateWidget(NeuronGuideDrift oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.period == widget.period &&
        oldWidget.amplitude == widget.amplitude) {
      return;
    }

    // `force` para saltar el `return` temprano de `_apply`: el periodo y la
    // amplitud son parametros, no dependencias heredadas, asi que
    // `didChangeDependencies` no se entera de que cambiaron.
    _controller.duration = widget.period;
    _apply(force: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply({bool force = false}) {
    // TickerMode ademas del gate de reduce-motion: en una ruta inactiva Flutter
    // mutea los tickers, y con esto el controller ni arranca.
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

    // El estado quieto es el arranque del seno, que vale cero: las guias en su
    // posicion de siempre.
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(
        context,
        math.sin(_controller.value * 2 * math.pi) * widget.amplitude,
      ),
    );
  }
}
