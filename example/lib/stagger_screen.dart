import 'package:example/demo_section.dart';
import 'package:example/periodic_tick.dart';
import 'package:flutter/material.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Cuántas filas entran escalonadas.
const _rowCount = 6;

/// Alto de cada fila, con su separación.
const _rowHeight = 42.0;

/// Alto reservado para la lista entera.
///
/// **Fijo a propósito.** `ExpandLine` abre cada fila desde una línea, así que
/// mientras entran la columna mide casi nada y lo que está debajo se trepa
/// hasta arriba y vuelve a bajar. Eso no lee como escalonado, lee como que la
/// página salta. Con el alto reservado las filas se abren dentro de un marco
/// quieto, que es lo único que deja ver el efecto.
const double _listHeight = _rowCount * _rowHeight;

/// Cada cuánto vuelve a entrar la lista.
///
/// Más largo que `maxDelay` más la apertura de la última fila, o el escalonado
/// se corta antes de que el último hermano haya entrado.
const _replayPeriod = Duration(milliseconds: 2600);

/// El escalonado: los hermanos **no entran juntos**.
///
/// `Stagger` **da el retraso, no controla el reloj de nadie**: lo publica por
/// un `InheritedWidget` y quien lo lee es la animación de entrada del hijo. Acá
/// esa animación es `ExpandLine`, que es la única pieza del package que consulta
/// [Stagger.delayOf]. Un hijo que no lo lea entra igual, sin escalonar.
///
/// Se instancia **por item** y no por lista, justamente porque el caso de uso es
/// un `ListView.builder`: un widget que recibiera la lista entera no puede
/// alimentar un `itemBuilder` perezoso.
class StaggerScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<StaggerScreen> createState() => _StaggerScreenState();
}

class _StaggerScreenState extends State<StaggerScreen> {
  StaggerOrder _order = StaggerOrder.forward;

  /// Cuántas veces se pidió la entrada a mano.
  ///
  /// Va en la `key` por lo mismo que en la pantalla de revelado: `ExpandLine`
  /// corre su apertura al montarse y tampoco sabe rebobinar.
  int _manual = 0;

  @override
  Widget build(BuildContext context) {
    return PeriodicTick(
      // Ver la pantalla de revelado: la `key` remonta el reloj para que la
      // repetición manual no quede a merced del próximo tick. Acá entra
      // también el orden, que cambia lo que hay que volver a mirar.
      key: ValueKey('$_manual-$_order'),
      period: _replayPeriod,
      builder: (context, tick) => Column(
        children: [
          DemoSection(
            title: 'STAGGER + EXPAND LINE',
            caption:
                'Cada fila espera su turno y después se abre desde una línea. '
                'Los dos tramos importan: la línea aparece, se queda un '
                'momento, y recién ahí crece el alto. Sin esa pausa el efecto '
                'lee como un `scaleY` común.',
            child: SizedBox(
              height: _listHeight,
              child: KeyedSubtree(
                key: ValueKey(tick),
                child: Column(
                  children: [
                    for (var index = 0; index < _rowCount; index++)
                      Stagger(
                        index: index,
                        count: _rowCount,
                        order: _order,
                        child: const ExpandLine(
                          lineColor: astralChromaticA,
                          child: _Row(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<StaggerOrder>(
              segments: const [
                ButtonSegment(
                  value: StaggerOrder.forward,
                  label: Text('forward'),
                ),
                ButtonSegment(
                  value: StaggerOrder.reverse,
                  label: Text('reverse'),
                ),
                ButtonSegment(
                  value: StaggerOrder.random,
                  label: Text('random'),
                ),
              ],
              selected: {_order},
              onSelectionChanged: (selection) =>
                  setState(() => _order = selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: TextButton.icon(
              onPressed: () => setState(() => _manual++),
              icon: const Icon(Icons.replay),
              label: const Text('CORRER AHORA'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: _rowHeight - 8,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(color: astralInkFaint),
      child: const Text(
        'ELEMENTO DEL HUD',
        style: TextStyle(color: astralInk, fontSize: 12, letterSpacing: 2),
      ),
    );
  }
}
