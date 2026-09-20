import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';
import 'package:neuron_hud/src/stagger.dart';

part 'expand_line_painter.dart';
part 'expand_line_state.dart';

/// Abre un panel desde una linea horizontal fina hasta su alto completo.
///
/// Sale de `menu_open.mp4`, el video del blog oficial de PlatinumGames en
/// https://www.platinumgames.com/official-blog/article/10397: los paneles del
/// menu no aparecen, se **abren** — primero la linea brillante, despues el alto.
///
/// **Son dos tramos, y el primero es el que le da el caracter.** La linea
/// aparece a alto [lineHeight] y se queda ahi durante [lineHold] antes de que el
/// alto empiece a crecer. Sin esa pausa el efecto lee como un `scaleY` comun.
///
/// **Mide como su hijo a lo ancho**: lo unico que recorta es el alto. Un panel
/// que hoy se ajusta a su contenido lo sigue haciendo con este widget encima.
///
/// **Con «Reducir movimiento» prendido pinta el hijo a alto completo**, sin la
/// linea y sin arrancar ningun controller. Lo mismo con [duration] y [lineHold]
/// las dos en `Duration.zero`, que es la forma soportada de desactivarlo.
///
/// Si hay un [Stagger] arriba, la apertura espera el retraso que publique antes
/// de arrancar.
class ExpandLine extends StatefulWidget {
  /// Abre un panel desde una linea horizontal fina.
  const new({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 280),
    this.lineColor = astralInk,
    this.lineHeight = 1,
    this.lineHold = const Duration(milliseconds: 80),
    this.curve = Curves.easeOutCubic,
    this.alignment = Alignment.center,
  });

  /// El panel que se abre.
  final Widget child;

  /// Cuanto tarda en abrirse, sin contar [lineHold].
  final Duration duration;

  /// Color de la linea del primer tramo.
  final Color lineColor;

  /// Alto de la linea, y piso del alto de la caja.
  final double lineHeight;

  /// Cuanto se queda la linea sola antes de que el alto empiece a crecer.
  final Duration lineHold;

  /// Curva del segundo tramo.
  final Curve curve;

  /// Desde donde crece el alto, y donde va la linea.
  ///
  /// Es un `Alignment` absoluto y no un `AlignmentDirectional` a proposito:
  /// este package no puede exigir un `Directionality` ancestro, que es
  /// justamente lo que hace inservible a `SizeTransition`.
  final Alignment alignment;

  @override
  State<ExpandLine> createState() => _ExpandLineState();
}
