import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  /// Monta el reloj y deja el último desplazamiento que publicó.
  Widget montar({
    required List<double> registro,
    double amplitude = neuronGuideDriftAmplitude,
    Duration period = const Duration(milliseconds: 1000),
    bool disableAnimations = false,
    bool tickerEnabled = true,
  }) {
    return MaterialApp(
      // El `MediaQuery` va adentro del `MaterialApp` y no afuera: el
      // `MaterialApp` arma el suyo desde la ventana y pisaría uno externo.
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: TickerMode(
          enabled: tickerEnabled,
          child: NeuronGuideDrift(
            amplitude: amplitude,
            period: period,
            builder: (context, drift) {
              registro.add(drift);
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      ),
    );
  }

  group('neuronGuideDriftPeriod =>', () {
    test('dos semillas distintas dan períodos distintos', () {
      // Veinte cajas montadas en el mismo frame y con el mismo período se
      // mueven todas juntas, y eso lee como si la pantalla temblara.
      expect(neuronGuideDriftPeriod(0), isNot(neuronGuideDriftPeriod(1)));
    });

    test('la misma semilla da siempre el mismo período', () {
      expect(neuronGuideDriftPeriod(5), neuronGuideDriftPeriod(5));
    });

    test('el período cae en el rango de la fórmula', () {
      for (var seed = 0; seed < 32; seed++) {
        final period = neuronGuideDriftPeriod(seed);

        expect(period.inMilliseconds, greaterThanOrEqualTo(3200));
        expect(period.inMilliseconds, lessThanOrEqualTo(4400));
      }
    });

    test('es más lento que el barrido, que es más lento que el ruido', () {
      // Tres capas al mismo ritmo se leen como una sola cosa parpadeando.
      expect(
        neuronGuideDriftPeriod(0).inMilliseconds,
        greaterThan(neuronSweepPeriod(0).inMilliseconds),
      );
    });

    test('una semilla negativa sigue dando un período del rango', () {
      // El `%` de Dart sobre enteros devuelve siempre un valor no negativo.
      expect(
        neuronGuideDriftPeriod(-3).inMilliseconds,
        greaterThanOrEqualTo(3200),
      );
    });
  });

  group('NeuronGuideDrift =>', () {
    testWidgets('arranca en cero y se mueve con el tiempo', (tester) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro));
      // Calentamiento: el primer tick del `Ticker` reporta `elapsed` cero.
      await tester.pump();

      expect(registro.last, closeTo(0, 1e-9));

      await tester.pump(const Duration(milliseconds: 250));

      // Un cuarto de ciclo: el seno vale uno, así que el desplazamiento es la
      // amplitud entera.
      expect(registro.last, closeTo(neuronGuideDriftAmplitude, 0.001));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('va para los dos lados: es un seno, no una rampa', (
      tester,
    ) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Tres cuartos de ciclo: el seno vale menos uno. Una rampa las correría
      // siempre para el mismo lado y tendría que volver de un salto al cerrar.
      expect(registro.last, closeTo(-neuronGuideDriftAmplitude, 0.001));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con amplitud cero no se mueve nunca', (tester) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro, amplitude: 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro, everyElement(0));
    });

    testWidgets('con período cero tampoco: el controller ni arranca', (
      tester,
    ) async {
      final registro = <double>[];

      await tester.pumpWidget(
        montar(registro: registro, period: Duration.zero),
      );
      await tester.pump();

      expect(registro, everyElement(0));
    });

    testWidgets('con «Reducir movimiento» las guías quedan quietas', (
      tester,
    ) async {
      final registro = <double>[];

      await tester.pumpWidget(
        montar(registro: registro, disableAnimations: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro, everyElement(0));
    });

    testWidgets('en una ruta inactiva no gasta: el TickerMode lo apaga', (
      tester,
    ) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro, tickerEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro, everyElement(0));
    });

    testWidgets('prender el TickerMode en vivo lo arranca', (tester) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro, tickerEnabled: false));
      await tester.pump();

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro.last, closeTo(neuronGuideDriftAmplitude, 0.001));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar el período en vivo reprograma el controller', (
      tester,
    ) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();

      // Un `ListView.builder` reusa el `Element` de una fila para otra: el
      // ritmo tiene que irse con la fila, no quedarse en el slot.
      await tester.pumpWidget(
        montar(registro: registro, period: const Duration(milliseconds: 2000)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Un cuarto del período nuevo, no del viejo.
      expect(registro.last, closeTo(neuronGuideDriftAmplitude, 0.001));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar la amplitud en vivo la aplica', (tester) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();

      await tester.pumpWidget(montar(registro: registro, amplitude: 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro.last, closeTo(10, 0.001));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un rebuild sin cambios no reprograma nada', (tester) async {
      final registro = <double>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      final aMitadDeCamino = registro.last;

      // Mismo período y misma amplitud: el `didUpdateWidget` sale por el
      // `return` temprano y el controller sigue donde estaba.
      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();

      expect(registro.last, closeTo(aMitadDeCamino, 0.05));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
