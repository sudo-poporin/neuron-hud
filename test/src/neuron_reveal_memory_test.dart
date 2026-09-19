import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  setUp(resetNeuronRegistry);

  Widget montar(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

  group('NeuronRevealMemory =>', () {
    testWidgets('pinta a su hijo tal cual', (tester) async {
      await tester.pumpWidget(
        montar(const NeuronRevealMemory(owner: '123', child: Text('hola'))),
      );

      expect(find.text('hola'), findsOneWidget);
    });

    testWidgets('al desmontarse olvida lo que su dueño había revelado', (
      tester,
    ) async {
      await tester.pumpWidget(
        montar(const NeuronRevealMemory(owner: '123', child: SizedBox())),
      );

      markNeuronRevealed(neuronRevealKey('123', 'cover'));

      // Es lo que hace que el scroll siga re-revelando: un `ListView.builder`
      // destruye lo que sale del viewport, y con la fila se va su memoria.
      await tester.pumpWidget(montar(const SizedBox()));

      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'cover')), isFalse);
    });

    testWidgets('cambiar de dueño olvida al anterior y no al nuevo', (
      tester,
    ) async {
      await tester.pumpWidget(
        montar(const NeuronRevealMemory(owner: '123', child: SizedBox())),
      );

      markNeuronRevealed(neuronRevealKey('123', 'cover'));
      markNeuronRevealed(neuronRevealKey('456', 'cover'));

      // Un `ListView.builder` recicla el slot de una fila para otra: lo que
      // recordaba el `Element` ya no es de nadie.
      await tester.pumpWidget(
        montar(const NeuronRevealMemory(owner: '456', child: SizedBox())),
      );

      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'cover')), isFalse);
      expect(neuronAlreadyRevealed(neuronRevealKey('456', 'cover')), isTrue);
    });

    testWidgets('reconstruir con el mismo dueño no olvida nada', (
      tester,
    ) async {
      await tester.pumpWidget(
        montar(const NeuronRevealMemory(owner: '123', child: SizedBox())),
      );

      markNeuronRevealed(neuronRevealKey('123', 'cover'));

      await tester.pumpWidget(
        montar(
          const NeuronRevealMemory(owner: '123', child: Text('otro hijo')),
        ),
      );

      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'cover')), isTrue);
    });
  });
}
