import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';

part 'chromatic_burst_render.dart';
part 'chromatic_burst_state.dart';

/// Desfase RGB en rafaga sobre el hijo: la aberracion cromatica del HUD.
///
/// Sale de `logo_animation.mp4`, el video del blog oficial de PlatinumGames en
/// https://www.platinumgames.com/official-blog/article/10397, donde el pico de
/// aberracion es cian a la izquierda y rojo a la derecha.
///
/// **Es un pico, no un continuo ni un periodico visible.** En la referencia
/// ocurre una sola vez, en el momento de la resolucion, y despues el logo queda
/// limpio. Con [period] en `null` el widget hace exactamente eso: dispara una
/// vez y no vuelve.
///
/// **Entre rafagas el hijo no tiene ni una copia extra en el arbol.** Las dos
/// capas tenidas existen solo durante los milisegundos de la rafaga, que es lo
/// que hace tolerable el peor caso de veinte cajas simultaneas.
///
/// **Con «Reducir movimiento» prendido no se crea ni un `Timer`** y el hijo se
/// pinta limpio. No es una cortesia: aberracion cromatica mas parpadeo rapido
/// es el patron fotosensible.
///
/// **El hijo entra al arbol una sola vez.** Los dos fantasmas se pintan desde
/// un render object propio, asi que no hay copias, no hay `State` duplicado y
/// el hijo puede llevar un `GlobalKey`.
///
/// **Si el subarbol del hijo necesita compositing** —un `Opacity` con alpha
/// intermedio, un `ColorFiltered`, un `RepaintBoundary`, una platform view— el
/// efecto se saltea los fantasmas y pinta el hijo tal cual. Repintar un
/// subarbol que retiene un handle de capa la **muda** en vez de duplicarla,
/// asi que los fantasmas saldrian invisibles igual: mejor no pintarlos que
/// dejar el canvas a medias.
class ChromaticBurst extends StatefulWidget {
  /// Desfase RGB en rafaga sobre el hijo.
  const new({
    required this.child,
    super.key,
    this.offset = 4,
    this.maxTilt = 25,
    this.colorA = astralChromaticA,
    this.colorB = astralChromaticB,
    this.blendMode = BlendMode.plus,
    this.burstDuration = const Duration(milliseconds: 120),
    this.period = const Duration(seconds: 4),
    this.jitter = 0.5,
    this.seed = 0,
  });

  /// Contenido sobre el que se pinta el desfase.
  final Widget child;

  /// Desplazamiento maximo de cada fantasma, en pixeles logicos.
  final double offset;

  /// Cuanto se puede inclinar el eje del desfase, en grados.
  ///
  /// **Es un maximo, y se sortea de nuevo en cada rafaga**, entre `-maxTilt` y
  /// `+maxTilt`.
  ///
  /// **Y ademas sortea de que lado sale cada color.** El eje se da vuelta 180
  /// grados la mitad de las veces, asi que a veces [colorA] queda a la
  /// izquierda y a veces a la derecha. Va en el mismo knob porque es la misma
  /// cosa: intercambiar los dos colores es identico a girar el eje media
  /// vuelta, y separarlo en un `bool` seria un segundo parametro para expresar
  /// una rotacion.
  ///
  /// **Cambia en cada aparicion, no solo en cada rafaga.** Sale de un
  /// generador sin semilla —el unico del widget—, porque en el modo de disparo
  /// unico hay un solo destello por montaje: con la semilla, la misma portada
  /// se inclinaba siempre igual. El precio es que la inclinacion no es
  /// reproducible y un test solo puede aseverar rangos y variacion.
  ///
  /// **Con 0 no hay ni inclinacion ni intercambio**: el desfase queda
  /// horizontal puro con [colorA] a la izquierda, que es lo que hace
  /// `logo_animation.mp4` —ahi el pico es cian a la izquierda y rojo a la
  /// derecha, siempre igual—. Es el modo referencia, y el que usan los tests
  /// que miden un pixel concreto.
  ///
  /// El default de 12 grados se nota sin parecer otro efecto: sobre los 4 px de
  /// [offset] son menos de un pixel de componente vertical. **Se escala con
  /// [offset]**, asi que un call site que desfase mucho —el mensaje de carga de
  /// la busqueda usa 40— ve mucha mas inclinacion con el mismo angulo.
  ///
  /// Los dos fantasmas siguen siendo opuestos: uno va a `tilt` y el otro a
  /// `tilt + 180`, asi que la polaridad de color no cambia con la inclinacion.
  final double maxTilt;

  /// Color de la capa que se corre a la izquierda.
  final Color colorA;

  /// Color de la capa que se corre a la derecha.
  final Color colorB;

  /// Como se componen los fantasmas contra el fondo.
  ///
  /// `plus` y `screen` dan el desfase RGB real; una opacidad simple da barro.
  final BlendMode blendMode;

  /// Cuanto dura una rafaga.
  final Duration burstDuration;

  /// Cada cuanto se repite la rafaga.
  ///
  /// Con `null` es un **disparo unico**: dispara al montarse y no vuelve. Es el
  /// modo del orquestador de la secuencia de revelado.
  ///
  /// Cambiar el valor en vivo se toma en la pausa siguiente, pero **pasar de
  /// `null` a una duracion no arranca nada**: el disparo unico ya termino y no
  /// hay pausa donde tomarlo. Para eso hace falta remontar el widget, que es lo
  /// que pasa naturalmente cuando el orquestador cambia de fase.
  final Duration? period;

  /// Cuanto varia la pausa entre rafagas, de 0 a 1 sobre [period].
  ///
  /// Con 0,5 la pausa cae entre la mitad y una vez y media de [period]. Se
  /// recorta a `0..1`.
  final double jitter;

  /// Semilla de la fase inicial y del jitter.
  ///
  /// **No gobierna la inclinacion.** Esa sale de un generador sin semilla, a
  /// proposito: tiene que cambiar en cada aparicion, y con un disparo unico la
  /// semilla la dejaba clavada. Ver `maxTilt`.
  ///
  /// **Se lee una sola vez, al montar.** Cambiarla en vivo no tiene efecto:
  /// el generador se crea en el `State` y no se recrea.
  ///
  /// La fase inicial es lo que evita que veinte cajas de una lista destellen al
  /// unisono. Derivar la semilla del item —`seed: game.id`— le da a cada fila su
  /// propio ritmo.
  final int seed;

  @override
  State<ChromaticBurst> createState() => _ChromaticBurstState();
}

/// Pinta los dos fantasmas de [ChromaticBurst] sobre su hijo.
class _ChromaticBurstLayer extends SingleChildRenderObjectWidget {
  const new({
    required this.amount,
    required this.offset,
    required this.tilt,
    required this.colorA,
    required this.colorB,
    required this.blendMode,
    required super.child,
  });

  final double amount;
  final double offset;
  final double tilt;
  final Color colorA;
  final Color colorB;
  final BlendMode blendMode;

  @override
  RenderChromaticBurst createRenderObject(BuildContext context) =>
      RenderChromaticBurst(
        amount: amount,
        offset: offset,
        tilt: tilt,
        colorA: colorA,
        colorB: colorB,
        blendMode: blendMode,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderChromaticBurst renderObject,
  ) {
    renderObject
      ..amount = amount
      ..offset = offset
      ..tilt = tilt
      ..colorA = colorA
      ..colorB = colorB
      ..blendMode = blendMode;
  }
}
