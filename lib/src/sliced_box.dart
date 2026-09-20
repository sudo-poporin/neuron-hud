import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';

part 'sliced_box_painter.dart';
part 'sliced_box_render.dart';
part 'sliced_box_state.dart';

/// Una banda del corte: donde arranca, cuanto mide y para donde se corre. Todo
/// en fracciones del alto, salvo el sentido, que es un factor de -1 a 1.
///
/// Es publico porque [RenderSlicedBox] lo expone, y un tipo privado en una API
/// publica no pasa `library_private_types_in_public_api`.
typedef SlicedBand = ({double top, double height, double shift});

/// Bandas horizontales desplazadas sobre el hijo, en rafaga.
///
/// Sale de `logo_animation.mp4`, el video del blog oficial de PlatinumGames en
/// https://www.platinumgames.com/official-blog/article/10397, donde despues del
/// pico de aberracion cromatica aparecen bandas horizontales corridas con
/// lineas largas hacia los lados.
///
/// **El slicing es posterior al pico, no simultaneo.** Son fases, no capas
/// prendidas a la vez: el orquestador de la secuencia las corre en orden.
///
/// **Desplaza contenido real**: cada banda repinta al hijo recortado y corrido.
/// La banda queda quieta y su contenido se mueve, que es el efecto; una franja
/// pintada encima seria mas barata pero no es slicing.
///
/// **Entre rafagas el hijo no tiene ni una copia extra en el arbol.**
///
/// **Con «Reducir movimiento» prendido no se crea ni un `Timer`** y el hijo se
/// pinta sin cortes ni streaks.
///
/// **El hijo entra al arbol una sola vez.** Cada banda se pinta desde un render
/// object propio, asi que no hay copias, no hay `State` duplicado y el hijo
/// puede llevar un `GlobalKey`.
///
/// **Si el subarbol del hijo necesita compositing** el efecto se saltea las
/// bandas y pinta el hijo tal cual. Los streaks se pintan igual: no repintan al
/// hijo, asi que no tienen el problema.
class SlicedBox extends StatefulWidget {
  /// Bandas horizontales desplazadas sobre el hijo.
  const new({
    required this.child,
    super.key,
    this.sliceCount = 2,
    this.sliceOffset = 8,
    this.streaks = true,
    this.streakColor = astralInk,
    this.streakOverflow = 24,
    this.streakStrokeWidth = 1,
    this.burstDuration = const Duration(milliseconds: 90),
    this.period = const Duration(seconds: 6),
    this.jitter = 0.5,
    this.seed = 0,
  });

  /// Contenido que se corta.
  final Widget child;

  /// Cuantas bandas se cortan por rafaga.
  ///
  /// Con 0 o menos no se corta nada.
  final int sliceCount;

  /// Desplazamiento maximo en X de una banda, en pixeles logicos.
  final double sliceOffset;

  /// Si se pintan las lineas largas hacia los lados.
  final bool streaks;

  /// Color de los streaks.
  final Color streakColor;

  /// Pixeles que los streaks se extienden mas alla de la caja, de los dos
  /// lados.
  ///
  /// Dentro de un ancestro que clipee —un `ClipRRect` de tarjeta— el desborde
  /// se recorta y el efecto se pierde.
  final double streakOverflow;

  /// Ancho del trazo de los streaks.
  final double streakStrokeWidth;

  /// Cuanto dura una rafaga.
  final Duration burstDuration;

  /// Cada cuanto se repite la rafaga.
  ///
  /// Con `null` es un disparo unico: dispara al montarse y no vuelve.
  ///
  /// Cambiar el valor en vivo se toma en la pausa siguiente, pero **pasar de
  /// `null` a una duracion no arranca nada**: el disparo unico ya termino y no
  /// hay pausa donde tomarlo. Para eso hace falta remontar el widget.
  final Duration? period;

  /// Cuanto varia la pausa entre rafagas, de 0 a 1 sobre [period].
  final double jitter;

  /// Semilla de las bandas, de la fase inicial y del jitter.
  ///
  /// **Se lee una sola vez, al montar.** Cambiarla en vivo no tiene efecto:
  /// el generador se crea en el `State` y no se recrea.
  final int seed;

  @override
  State<SlicedBox> createState() => _SlicedBoxState();
}

/// Pinta las bandas de [SlicedBox] sobre su hijo.
class _SlicedBoxLayer extends SingleChildRenderObjectWidget {
  const new({
    required this.slices,
    required this.sliceOffset,
    required this.direction,
    required this.streaks,
    required this.streakColor,
    required this.streakOverflow,
    required this.streakStrokeWidth,
    required super.child,
  });

  final List<SlicedBand> slices;
  final double sliceOffset;
  final double direction;
  final bool streaks;
  final Color streakColor;
  final double streakOverflow;
  final double streakStrokeWidth;

  @override
  RenderSlicedBox createRenderObject(BuildContext context) => RenderSlicedBox(
    slices: slices,
    sliceOffset: sliceOffset,
    direction: direction,
    streaks: streaks,
    streakColor: streakColor,
    streakOverflow: streakOverflow,
    streakStrokeWidth: streakStrokeWidth,
  );

  @override
  void updateRenderObject(BuildContext context, RenderSlicedBox renderObject) {
    renderObject
      ..slices = slices
      ..sliceOffset = sliceOffset
      ..direction = direction
      ..streaks = streaks
      ..streakColor = streakColor
      ..streakOverflow = streakOverflow
      ..streakStrokeWidth = streakStrokeWidth;
  }
}
