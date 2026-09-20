import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/neuron_registry.dart';

/// Le da a una fila la memoria de lo que ya revelo, mientras la fila viva.
///
/// Envuelve al item de una lista y se lleva sus claves del registro cuando el
/// item se destruye. Es la mitad que convierte un registro global en uno con
/// alcance de fila, y con eso separa los dos casos que remontan un revelado:
///
/// - **El vuelo de un `Hero` no destruye la fila.** Cambia lo que cuelga del
///   `Hero` —dos veces por vuelo, una al empezar y otra al terminar— y arma una
///   copia mas en el overlay. La fila sigue montada, asi que la memoria sigue
///   ahi y ninguna de esas copias vuelve a revelar.
/// - **El scroll si la destruye.** Un `ListView.builder` tira lo que sale del
///   viewport; cuando vuelve, este `State` es otro, el registro ya no tiene sus
///   claves y el elemento se revela de nuevo. Que es lo que se decidio que
///   tiene que pasar.
class NeuronRevealMemory extends StatefulWidget {
  /// Le da a una fila la memoria de lo que ya revelo.
  const new({required this.owner, required this.child, super.key});

  /// Identidad de la fila: la misma que arma las claves de sus partes.
  final String owner;

  /// La fila.
  final Widget child;

  @override
  State<NeuronRevealMemory> createState() => _NeuronRevealMemoryState();
}

class _NeuronRevealMemoryState extends State<NeuronRevealMemory> {
  @override
  void didUpdateWidget(NeuronRevealMemory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.owner == widget.owner) return;

    // El `Element` se reuso para otra fila, asi que lo que recordaba ya no es de
    // nadie. **Hoy no pasa**: las tres listas keyean sus filas por identidad, y
    // una key que cambia remonta en vez de reusar. Se queda igual porque el dia
    // que una lista deje de keyear, el sintoma seria un juego que hereda la
    // memoria de otro, y eso no se ve mirando la app.
    forgetNeuronRevealed(oldWidget.owner);
  }

  @override
  void dispose() {
    forgetNeuronRevealed(widget.owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      // **La `key` es lo que hace que un dueño nuevo remonte al hijo.** Limpiar
      // el registro no alcanza: el `Element` del hijo es el mismo, y un
      // `NeuronReveal` que ya terminó conserva su estado, así que la fila nueva
      // aparecería resuelta sin revelarse.
      KeyedSubtree(key: ValueKey(widget.owner), child: widget.child);
}
