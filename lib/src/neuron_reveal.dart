import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';
import 'package:neuron_hud/src/block_noise.dart';
import 'package:neuron_hud/src/chromatic_burst.dart';
import 'package:neuron_hud/src/dot_matrix.dart';
import 'package:neuron_hud/src/guide_lines.dart';
import 'package:neuron_hud/src/neuron_timeline.dart';
import 'package:neuron_hud/src/sliced_box.dart';
import 'package:neuron_hud/src/stagger.dart';

part 'neuron_reveal_layers.dart';
part 'neuron_reveal_render.dart';
part 'neuron_reveal_run.dart';
part 'neuron_reveal_state.dart';

/// Corre la secuencia de revelado del HUD sobre su hijo.
///
/// Es el orquestador del sistema: arma la pila de capas —`GuideLines`,
/// `BlockNoise` y `DotMatrix`— y les mueve el `progress` segun la fase, y monta
/// `ChromaticBurst` y `SlicedBox` en la suya.
///
/// **La polaridad de las capas es al reves de lo que parece.** En las capas de
/// este package `progress` en 0 pinta la capa **completa** y en 1 no pinta nada,
/// que es la inversa a `HoldProgressBorderPainter`. Una capa entra llevando su
/// `progress` de 1 a 0 y sale llevandolo de 0 a 1.
///
/// **La formacion corre sin esperar a nadie y la resolucion espera al
/// contenido.** `guides`, `dots` y `noise` levantan el andamio apenas el widget
/// se monta; con [ready] en `false` el revelado se para donde empieza la primera
/// fase de resolucion y ahi se queda, con el esqueleto puesto y el contenido
/// oculto, hasta que el call site lo ponga en `true`.
///
/// **Es opcional.** Sin el, cada efecto del package corre en bucle
/// independiente, que es el modo del rol *ocupado*.
///
/// **Con «Reducir movimiento» prendido pinta el hijo pelado**, sin capas, sin
/// controller y sin timers.
///
/// El hijo se **remonta tres veces** a lo largo de un revelado completo: al
/// entrar en `chromatic`, al entrar en `slice` y al terminar. Es inherente a
/// montar los dos efectos de rafaga, que con `period: null` disparan al montarse
/// y no se dejan disparar de otra forma: meter un wrapper arriba del hijo lo
/// saca de su slot y Flutter infla el subarbol de nuevo. Para un texto es
/// gratis; para una imagen es una relectura del `ImageCache`, no una descarga.
class NeuronReveal extends StatefulWidget {
  /// Corre la secuencia de revelado del HUD sobre su hijo.
  const new({
    required this.child,
    super.key,
    this.phases = NeuronPhase.values,
    this.ready = true,
    this.fastPathAfter,
    this.alreadyRevealed = false,
    this.onRevealStart,
    this.durations,
    this.chromaticA = astralChromaticA,
    this.chromaticB = astralChromaticB,
    this.chromaticOffset = 4,
    this.ink = astralInk,
    this.seed = 0,
  });

  /// El contenido que se revela.
  final Widget child;

  /// Que fases corren.
  ///
  /// Dice **cuales**, no en que orden: el orden es siempre el de
  /// [NeuronPhase.values]. Quitar fases para un revelado mas corto es valido —el
  /// contrato del rol texto pide una lista sin [NeuronPhase.slice]—, y con la
  /// lista vacia se pinta el hijo pelado.
  final List<NeuronPhase> phases;

  /// Si el contenido ya esta.
  ///
  /// Con `false` la formacion corre igual y el revelado se para donde empieza la
  /// resolucion, con el esqueleto puesto y el contenido oculto.
  ///
  /// **Necesita al menos una fase de resolucion para significar algo.** Con
  /// unas [phases] que no incluyan ninguna de `condense`, `chromatic`, `slice`
  /// ni `settle` no hay donde parar, y el revelado corre entero sin esperar.
  final bool ready;

  /// Si el contenido llego antes de esto, no se lo revela.
  ///
  /// Se mide desde que el widget se monta. Una portada en cache aparece al
  /// instante —`CachedNetworkImage` la sirve con `fadeInDuration:
  /// Duration.zero`, que es deliberado— y correrle una secuencia de 800 ms
  /// encima la haria tardar un orden de magnitud mas que antes.
  ///
  /// **Se lee una sola vez, al montar.** Cambiarlo en vivo no reprograma la
  /// ventana, igual que la semilla de los efectos de rafaga.
  final Duration? fastPathAfter;

  /// Si este elemento ya se revelo antes.
  ///
  /// Quien lo usa lleva el registro de ids ya revelados: un `ListView.builder`
  /// destruye lo que sale del viewport y lo reconstruye al volver, y sin memoria
  /// cada scroll re-revelaria todo.
  final bool alreadyRevealed;

  /// Se dispara en el frame en que el revelado arranca, no al terminarlo.
  ///
  /// Marcar al arrancar es lo que resuelve el caso del `Hero`: cuando un `Hero`
  /// vuela, Flutter reconstruye el hijo para el overlay y ese [NeuronReveal]
  /// nuevo arranca en cero. Consultando el registro, la reconstruccion ve el id
  /// y pinta el final.
  ///
  /// **Se dispara tambien cuando [fastPathAfter] corta el revelado**, aunque ahi
  /// no haya animacion que proteger: el registro significa «esto ya se mostro»,
  /// no «esto se animo». No se dispara con [alreadyRevealed] —no hay revelado
  /// que arrancar— ni con «Reducir movimiento» —no hubo revelado, y una
  /// reconstruccion posterior tampoco lo va a correr—.
  ///
  /// **Corre en fase de build: no puede llamar `setState`.**
  final VoidCallback? onRevealStart;

  /// Override parcial de las duraciones por fase.
  final Map<NeuronPhase, Duration>? durations;

  /// Color de la capa que se corre a la izquierda en el pico de aberracion.
  ///
  /// El default es el cian del frame del pico de `logo_animation.mp4`. Entra por
  /// parametro porque este package no puede leer el tema de su consumidor, y hay
  /// consumidores que quieren el pico en su propia paleta.
  final Color chromaticA;

  /// Color de la capa que se corre a la derecha en el pico de aberracion.
  final Color chromaticB;

  /// Cuanto se corre cada fantasma del pico, en pixeles logicos.
  ///
  /// Es una medida absoluta, no una fraccion: el mismo valor lee muy distinto
  /// sobre un texto de pantalla que sobre una portada de 90 px de ancho.
  final double chromaticOffset;

  /// Color base de las tres capas del revelado.
  ///
  /// El default es el blanco del HUD, que es el de la referencia y el que
  /// contrasta sobre un fondo oscuro. **Sobre un fondo claro no se ve**, y un
  /// package no puede leer el tema de su consumidor: quien lo use pasa la tinta
  /// que su fondo pida.
  ///
  /// **La alpha del color que se pasa se ignora**: cada capa aplica la suya, que
  /// es lo que las separa entre si. Con el default, las tres dan exactamente
  /// [astralInk], [astralInkDim] y [astralInkFaint].
  final Color ink;

  /// Semilla del layout de las capas y de los efectos.
  ///
  /// Derivarla del item —`seed: game.id`— le da a cada fila su propio patron.
  final int seed;

  @override
  State<NeuronReveal> createState() => _NeuronRevealState();
}

/// Aplica una opacidad al contenido **sin componer** cuando es opaco.
///
/// Existe porque `Opacity` no sirve acá: `RenderOpacity` declara
/// `alwaysNeedsCompositing => child != null && _alpha > 0`, asi que fuerza capa
/// con alpha 255 igual que con alpha 128, y una capa abajo de los efectos de
/// rafaga les impide repintar al hijo.
class _ContentOpacity extends SingleChildRenderObjectWidget {
  const new({required this.opacity, required super.child});

  final double opacity;

  @override
  RenderContentOpacity createRenderObject(BuildContext context) =>
      RenderContentOpacity(opacity);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderContentOpacity renderObject,
  ) {
    renderObject.opacity = opacity;
  }
}
