import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';

/// Corchetes en L en las cuatro esquinas del hijo.
///
/// Es la capa フレーム del diagrama de descomposicion del HUD de Astral Chain.
/// **Son angulos rectos, no chaflanes diagonales**: cada esquina son dos
/// segmentos, uno horizontal y uno vertical, que no llegan a tocarse con los
/// de las esquinas vecinas.
///
/// A diferencia de las otras tres capas no toma `progress`: en la referencia el
/// marco queda despues de que el elemento resolvio.
///
/// **Con `child` en null no pinta nada.** `CustomPaint` sin hijo se dimensiona
/// por su parametro `size`, que por defecto es `Size.zero`. Sin hijo hay que
/// envolverlo en algo que le de tamano.
class TechFrame extends StatelessWidget {
  /// Corchetes en L en las cuatro esquinas del hijo.
  const new({
    super.key,
    this.bracketLength = 12,
    this.strokeWidth = 1,
    this.color = astralInk,
    this.cornerOffsets = const <Offset>[],
    this.child,
  });

  /// Largo de cada segmento del corchete, en pixeles logicos.
  ///
  /// Se recorta a la mitad del lado mas corto: en una caja de 12 de alto, un
  /// corchete de 12 haria que el segmento de arriba y el de abajo se
  /// encontraran en el medio, y el marco se leeria como un rectangulo cerrado.
  final double bracketLength;

  /// Ancho del trazo.
  ///
  /// `PaintingStyle.stroke` centra el trazo sobre el path, y los ocho
  /// segmentos van sobre los bordes mismos de la caja (`x = 0`, `x = right`,
  /// `y = 0`, `y = bottom`): la mitad de cada trazo cae fuera de la caja. Con
  /// 1 es medio pixel; con 3 o 4 ya se pierde un par de pixeles por lado, y
  /// dentro de un ancestro que clipee —un `ClipRRect` de tarjeta, el caso de
  /// uso obvio— el marco pierde esa mitad en los cuatro lados.
  final double strokeWidth;

  /// Color de los corchetes.
  final Color color;

  /// Cuanto se corre cada esquina de su lugar, en pixeles logicos.
  ///
  /// En el orden en que se dibujan: superior izquierda, superior derecha,
  /// inferior izquierda, inferior derecha. Una lista mas corta —la vacia, que
  /// es el default— deja quietas a las que no nombra, asi que no hay largo que
  /// respetar ni assert que romper.
  ///
  /// **No cambia el tamano de nada.** Esto se pinta en un `foregroundPainter`,
  /// que dibuja sobre el hijo ya medido: correr una esquina mueve donde se
  /// pinta el corchete y el layout no se entera. Un corchete corrido hacia
  /// afuera se sale de la caja, y ahi vale la misma advertencia que
  /// [strokeWidth]: dentro de un ancestro que clipee, lo que se salga se
  /// pierde.
  ///
  /// **Este widget no tiene reloj**, igual que las otras tres capas de esta
  /// carpeta. Quien quiera ver las esquinas moverse le mueve estos valores
  /// desde afuera, que es lo que hace `NeuronCornerDrift`.
  final List<Offset> cornerOffsets;

  /// Contenido sobre el que se dibuja el marco.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: TechFramePainter(
        bracketLength: bracketLength,
        strokeWidth: strokeWidth,
        color: color,
        cornerOffsets: cornerOffsets,
      ),
      child: child,
    );
  }
}

/// Pinta los ocho segmentos de [TechFrame].
class TechFramePainter extends CustomPainter {
  /// Pinta los ocho segmentos de [TechFrame].
  const new({
    required this.bracketLength,
    required this.strokeWidth,
    required this.color,
    required this.cornerOffsets,
  });

  /// Largo de cada segmento, antes del recorte.
  final double bracketLength;

  /// Ancho del trazo.
  final double strokeWidth;

  /// Color de los corchetes.
  final Color color;

  /// Cuanto se corre cada esquina, en el orden en que se dibujan.
  final List<Offset> cornerOffsets;

  /// El desplazamiento de la esquina [index], o cero si no lo nombran.
  Offset _corner(int index) =>
      index < cornerOffsets.length ? cornerOffsets[index] : Offset.zero;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final length = math.min(bracketLength, size.shortestSide / 2);
    final right = size.width;
    final bottom = size.height;

    final topLeft = _corner(0);
    final topRight = _corner(1);
    final bottomLeft = _corner(2);
    final bottomRight = _corner(3);

    canvas
      // superior izquierda
      ..drawLine(topLeft, topLeft + Offset(length, 0), paint)
      ..drawLine(topLeft, topLeft + Offset(0, length), paint)
      // superior derecha
      ..drawLine(
        topRight + Offset(right - length, 0),
        topRight + Offset(right, 0),
        paint,
      )
      ..drawLine(
        topRight + Offset(right, 0),
        topRight + Offset(right, length),
        paint,
      )
      // inferior izquierda
      ..drawLine(
        bottomLeft + Offset(0, bottom - length),
        bottomLeft + Offset(0, bottom),
        paint,
      )
      ..drawLine(
        bottomLeft + Offset(0, bottom),
        bottomLeft + Offset(length, bottom),
        paint,
      )
      // inferior derecha
      ..drawLine(
        bottomRight + Offset(right - length, bottom),
        bottomRight + Offset(right, bottom),
        paint,
      )
      ..drawLine(
        bottomRight + Offset(right, bottom - length),
        bottomRight + Offset(right, bottom),
        paint,
      );
  }

  @override
  bool shouldRepaint(TechFramePainter oldDelegate) =>
      oldDelegate.bracketLength != bracketLength ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.cornerOffsets, cornerOffsets);
}
