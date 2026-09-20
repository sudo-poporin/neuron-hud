import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// En que orden entran los hermanos de un [Stagger].
enum StaggerOrder {
  /// Del primero al ultimo.
  forward,

  /// Del ultimo al primero.
  reverse,

  /// Una permutacion fija, derivada de la semilla.
  random,
}

/// Escalona la entrada de widgets hermanos.
///
/// Sale de `hud_inanimation.mp4` y de `menu_open.mp4`, los videos del blog
/// oficial de PlatinumGames en
/// https://www.platinumgames.com/official-blog/article/10397 y
/// https://www.platinumgames.com/official-blog/article/10422: los elementos del
/// HUD **no entran juntos**. Barra de HP arriba a la izquierda, despues el panel
/// de objetivos a la derecha, despues la esquina inferior izquierda. Cada uno
/// arranca su propia secuencia con un retraso respecto del anterior.
///
/// **Da el retraso, no controla el reloj de nadie.** Lo publica por un
/// `InheritedWidget`, y quien lo lee es la animacion de entrada del hijo
/// —[Stagger.delayOf]—. Un hijo que no lo lea entra igual, sin escalonar.
///
/// Se instancia **por item**, envolviendo la fila que ya existe:
///
/// ```dart
/// itemBuilder: (context, index) => Stagger(
///   index: index,
///   count: itemCount,
///   child: const _FilaDeBusqueda(),
/// )
/// ```
///
/// Es por item y no por lista justamente porque el caso de uso es un
/// `ListView.builder`: un widget que recibiera la lista entera no puede
/// alimentar un `itemBuilder` perezoso, que es donde [maxDelay] existe.
///
/// **[maxDelay] no es una comodidad.** El `itemBuilder` de un `ListView` recibe
/// el indice **global**: sin tope, el item 40 esperaria `40 x 90 ms` = 3,6
/// segundos antes de empezar a existir.
///
/// **Con «Reducir movimiento» prendido publica `Duration.zero`** y los hijos
/// entran sin escalonar.
class Stagger extends StatelessWidget {
  /// Escalona la entrada de widgets hermanos.
  const new({
    required this.index,
    required this.child,
    super.key,
    this.count = 0,
    this.step = const Duration(milliseconds: 90),
    this.maxDelay = const Duration(milliseconds: 450),
    this.jitter = 0,
    this.order = StaggerOrder.forward,
    this.seed = 0,
  });

  /// Que lugar ocupa este hijo entre sus hermanos.
  final int index;

  /// El hijo, con su animacion de entrada adentro.
  final Widget child;

  /// Cuantos hermanos hay.
  ///
  /// **Solo lo usan [StaggerOrder.reverse] y [StaggerOrder.random]**;
  /// [StaggerOrder.forward] no lo mira, y por eso el default es 0. Con un valor
  /// que no cubra al [index], los dos que si lo miran degradan a `forward`: una
  /// posicion negativa o fuera de la permutacion se veria peor que arrancar por
  /// el primero.
  final int count;

  /// Cuanto separa a un hermano del siguiente.
  final Duration step;

  /// Tope duro del retraso.
  final Duration maxDelay;

  /// Cuanto desordena el escalonado, de 0 a 1 sobre la posicion.
  ///
  /// Se recorta al rango. Con 0,5 el retraso cae entre la mitad y una vez y
  /// media del que le tocaria.
  final double jitter;

  /// En que orden entran.
  final StaggerOrder order;

  /// Semilla del jitter y de la permutacion de [StaggerOrder.random].
  final int seed;

  /// El retraso que publica el [Stagger] mas cercano.
  ///
  /// `Duration.zero` si no hay ninguno arriba, que es lo que deja a las
  /// animaciones de entrada funcionar sueltas.
  static Duration delayOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StaggerScope>()?.delay ??
      Duration.zero;

  @override
  Widget build(BuildContext context) {
    // maybeDisableAnimationsOf y no disableAnimationsOf: la segunda lanza si no
    // hay un MediaQuery ancestro, y este package no puede exigir uno para *no*
    // animar.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return _StaggerScope(
      delay: reduceMotion ? Duration.zero : _delay(),
      child: child,
    );
  }

  Duration _delay() {
    final position = _position() * _jitterFactor();
    if (position <= 0) return Duration.zero;

    final delay = step * position;

    return delay > maxDelay ? maxDelay : delay;
  }

  int _position() {
    // reverse y random necesitan saber cuantos son. Con un `count` que no cubra
    // al `index` degradan a forward.
    if (index < 0 || count <= index) return index;

    switch (order) {
      case StaggerOrder.forward:
        return index;
      case StaggerOrder.reverse:
        return count - 1 - index;
      case StaggerOrder.random:
        return ([for (var i = 0; i < count; i++) i]
          ..shuffle(math.Random(seed)))[index];
    }
  }

  double _jitterFactor() {
    final amount = jitter.clamp(0.0, 1.0);
    if (amount == 0) return 1;

    // `Random(seed + index)` fresco adentro de build, y no un generador
    // guardado: un `Random` como campo del widget impide el constructor `const`
    // y haria del retraso una funcion del historial de repintados.
    return 1 + (math.Random(seed + index).nextDouble() * 2 - 1) * amount;
  }
}

/// Publica el retraso ya calculado a los descendientes de un [Stagger].
class _StaggerScope extends InheritedWidget {
  const new({required this.delay, required super.child});

  final Duration delay;

  @override
  bool updateShouldNotify(_StaggerScope oldWidget) => oldWidget.delay != delay;
}
