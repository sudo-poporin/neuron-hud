import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';

part 'noise_sweep_painter.dart';
part 'noise_sweep_state.dart';

/// Las dos intensidades de [NoiseSweep].
enum NoiseSweepMode {
  /// Barrido legible: una banda atraviesa el elemento y eso lee como progreso.
  ///
  /// Es el que ocupa el rol *ocupado*, donde antes iba un brillo continuo.
  progress,

  /// El *sandstorm* de `menu_noize.mp4`: jirones de baja opacidad derivando
  /// sobre la superficie.
  ///
  /// Es ambiente, no señal. **No sirve solo para avisar que algo esta
  /// pasando.**
  ambient,
}

/// Un barrido continuo sobre el hijo, en dos intensidades.
///
/// Es el unico continuo con reloj de vsync del set, y el que ocupa el rol del
/// brillo continuo que habia antes: lo que comunica «esto esta pasando ahora»
/// es que sea **continuo**. Una rafaga cada tres segundos comunica inestabilidad, no
/// progreso.
///
/// Las dos intensidades salen de `menu_noize.mp4`, el video del blog oficial de
/// PlatinumGames en https://www.platinumgames.com/official-blog/article/10397,
/// donde el *sandstorm* resulto ser mucho mas sutil de lo que parecia: jirones
/// derivando sobre todo el plano, no una banda brillante que barre. Son dos
/// cosas distintas y hacen falta las dos.
///
/// **Con «Reducir movimiento» prendido el barrido queda quieto en el medio del
/// recorrido**, no en el arranque: la banda entra desde fuera del borde, asi
/// que en el arranque no se veria nada y el rol *ocupado* quedaria sin ninguna
/// marca visible.
class NoiseSweep extends StatefulWidget {
  /// Un barrido continuo sobre el hijo.
  const new({
    required this.child,
    super.key,
    this.mode = NoiseSweepMode.progress,
    this.color = astralInk,
    this.bandWidth = 0.18,
    this.trail = 0,
    this.period = const Duration(milliseconds: 1600),
    this.direction = AxisDirection.right,
    this.wispCount = 6,
    this.seed = 0,
  });

  /// Contenido sobre el que se barre.
  final Widget child;

  /// Que se pinta: el barrido de progreso o el ruido ambiente.
  final NoiseSweepMode mode;

  /// Color del barrido.
  final Color color;

  /// Ancho de la banda de [NoiseSweepMode.progress], como fraccion del eje.
  ///
  /// Es una fraccion y no pixeles para que el mismo widget funcione igual sobre
  /// un icono de 24 px y sobre una portada de 90x128. Se recorta a `0..1`, y con
  /// 0 no se pinta nada.
  ///
  /// No lo usa [NoiseSweepMode.ambient], que se mide con [wispCount].
  final double bandWidth;

  /// Largo de la estela que la banda deja detras, como fraccion del eje.
  ///
  /// En cero no hay estela y la banda es la de siempre: un gradiente simetrico
  /// que se apaga hacia los dos lados. Con un valor positivo la banda deja de
  /// ser simetrica y pasa a tener cabeza y cola —el color pleno adelante, un
  /// gradiente que se apaga detras—, que es lo que la lee como algo que
  /// **paso por ahi** en vez de como una franja que se traslada.
  ///
  /// Solo lo mira [NoiseSweepMode.progress]. El modo ambiente son jirones
  /// sueltos y no tienen recorrido del que dejar rastro.
  final double trail;

  /// Duracion de una vuelta completa del barrido.
  ///
  /// Con `Duration.zero` no se arranca el reloj y el barrido queda quieto en el
  /// medio del recorrido. Cambiarlo en vivo en cualquiera de los dos sentidos
  /// funciona.
  final Duration period;

  /// Hacia donde barre.
  final AxisDirection direction;

  /// Cantidad de jirones de [NoiseSweepMode.ambient].
  ///
  /// No lo usa [NoiseSweepMode.progress], que se mide con [bandWidth].
  final int wispCount;

  /// Semilla del campo de jirones.
  final int seed;

  @override
  State<NoiseSweep> createState() => _NoiseSweepState();
}
