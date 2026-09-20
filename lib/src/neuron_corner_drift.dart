import 'dart:math' as math;

import 'package:flutter/widgets.dart';

part 'neuron_corner_drift_state.dart';

/// Como se mueve cada esquina del marco.
enum NeuronCornerDriftMode {
  /// Sobre su diagonal: cada esquina entra hacia el centro de la caja y vuelve.
  ///
  /// El marco late abriendose y cerrandose. Las cuatro esquinas conservan su
  /// relacion con la caja, porque cada una se mueve sobre la recta que la une
  /// con el centro.
  inset,

  /// En x y en y por separado: cada esquina recorre una elipse chica.
  ///
  /// El marco deja de ser un rectangulo y flota. Es mas movimiento y menos
  /// estructura que [inset].
  free,

  /// Las dos a la vez: la entrada sobre la diagonal mas la elipse.
  ///
  /// Cada esquina se mete hacia el centro **y** ademas flota alrededor de donde
  /// llego. El desplazamiento total llega al doble de la amplitud, porque las
  /// dos componentes usan la misma.
  combined,
}

/// Cuanto se corre cada esquina del marco, en pixeles logicos.
///
/// Dos. En [NeuronCornerDriftMode.combined] las dos componentes usan esta misma
/// amplitud, asi que el desplazamiento total llega a cuatro pixeles: es el
/// mismo orden que la deriva de las guias, y en una portada de 90x128 es lo
/// maximo que se puede mover una marca de referencia sin dejar de serlo.
const neuronCornerDriftAmplitude = 2.0;

/// Cada cuanto una esquina completa su recorrido, desfasado por la semilla.
///
/// Entre 2,8 y 4 segundos, el mismo orden que la deriva de las guias: el marco
/// tambien es estructura, y estructura que se mueve rapido deja de servir de
/// referencia.
///
/// El `%` de Dart sobre enteros devuelve siempre un valor no negativo.
Duration neuronCornerDriftPeriod(int seed) =>
    Duration(milliseconds: 2800 + (seed % 5) * 300);

/// Mueve las cuatro esquinas del marco, cada una por su cuenta.
///
/// **Es el cuarto reloj del esqueleto**, y sigue el mismo reparto que los otros
/// tres: las capas no tienen reloj, y quien las mueve es un widget aparte.
///
/// **Las cuatro esquinas corren desfasadas entre si.** Con la misma fase el
/// marco entero se agranda y se achica al unisono, que lee como un latido —una
/// sola cosa— en vez de como cuatro marcas de referencia buscando su lugar. El
/// desfase es un cuarto de ciclo por esquina, corrido ademas por la semilla
/// para que dos cajas vecinas no coincidan.
///
/// **Nada de esto cambia el tamano del widget.** `TechFrame` pinta en un
/// `foregroundPainter` sobre el hijo ya medido, asi que correr una esquina
/// mueve donde se dibuja el corchete y el layout no se entera.
///
/// **Con «Reducir movimiento» prendido el controller ni arranca** y el builder
/// recibe las cuatro esquinas en cero.
class NeuronCornerDrift extends StatefulWidget {
  /// Mueve las cuatro esquinas del marco, cada una por su cuenta.
  const new({
    required this.amplitude,
    required this.period,
    required this.mode,
    required this.seed,
    required this.builder,
    super.key,
  });

  /// Cuanto se corre cada esquina, en pixeles logicos.
  ///
  /// En cero el builder recibe las cuatro en cero y no se crea ningun
  /// controller.
  final double amplitude;

  /// Cuanto dura el recorrido completo de una esquina.
  final Duration period;

  /// Como se mueve cada esquina.
  final NeuronCornerDriftMode mode;

  /// Semilla del desfase entre esquinas.
  final int seed;

  /// Construye el subarbol con el desplazamiento de las cuatro esquinas.
  ///
  /// Siempre cuatro, en el orden que espera `TechFrame.cornerOffsets`: superior
  /// izquierda, superior derecha, inferior izquierda, inferior derecha.
  final Widget Function(BuildContext context, List<Offset> corners) builder;

  @override
  State<NeuronCornerDrift> createState() => _NeuronCornerDriftState();
}
