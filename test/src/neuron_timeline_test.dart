import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  group('NeuronTimeline, la linea de tiempo', () {
    test('el total es la suma de las fases presentes', () {
      final completa = NeuronTimeline(phases: NeuronPhase.values);

      expect(
        completa.total,
        neuronPhaseDurations.values.reduce((a, b) => a + b),
      );

      final corta = NeuronTimeline(
        phases: const [NeuronPhase.guides, NeuronPhase.settle],
      );

      expect(
        corta.total,
        neuronPhaseDurations[NeuronPhase.guides]! +
            neuronPhaseDurations[NeuronPhase.settle]!,
      );
    });

    test('las fases corren en el orden del enum, no en el de la lista', () {
      // La lista viene al reves: la estabilizacion antes del andamio.
      final timeline = NeuronTimeline(
        phases: const [NeuronPhase.settle, NeuronPhase.guides],
      );

      // Al arranque corre `guides`, no `settle`.
      expect(timeline.frameAt(Duration.zero).phase, NeuronPhase.guides);
    });

    test('una fase repetida no se cuenta dos veces', () {
      final timeline = NeuronTimeline(
        phases: const [NeuronPhase.guides, NeuronPhase.guides],
      );

      expect(timeline.total, neuronPhaseDurations[NeuronPhase.guides]);
    });

    test('durations sobreescribe una fase sola', () {
      final timeline = NeuronTimeline(
        phases: const [NeuronPhase.guides, NeuronPhase.settle],
        durations: const {NeuronPhase.guides: Duration(milliseconds: 500)},
      );

      expect(
        timeline.durationOf(NeuronPhase.guides),
        const Duration(milliseconds: 500),
      );
      expect(
        timeline.durationOf(NeuronPhase.settle),
        neuronPhaseDurations[NeuronPhase.settle],
      );
    });

    test('una duracion negativa se toma como cero', () {
      final timeline = NeuronTimeline(
        phases: const [NeuronPhase.guides],
        durations: const {NeuronPhase.guides: Duration(milliseconds: -100)},
      );

      expect(timeline.total, Duration.zero);
    });

    test('durationOf de una fase ausente es cero', () {
      final timeline = NeuronTimeline(phases: const [NeuronPhase.guides]);

      expect(timeline.durationOf(NeuronPhase.slice), Duration.zero);
    });

    test('contains dice que fases corren', () {
      final timeline = NeuronTimeline(phases: const [NeuronPhase.guides]);

      expect(timeline.contains(NeuronPhase.guides), isTrue);
      expect(timeline.contains(NeuronPhase.slice), isFalse);
    });

    test('una lista vacia no dura nada y no tiene fase activa', () {
      final timeline = NeuronTimeline(phases: const []);

      expect(timeline.total, Duration.zero);
      expect(timeline.frameAt(Duration.zero).phase, isNull);
      expect(timeline.holdPoint, 1);
    });
  });

  group('NeuronTimeline, las ventanas de capa', () {
    final timeline = NeuronTimeline(phases: NeuronPhase.values);

    Duration startOf(NeuronPhase phase) {
      var cursor = Duration.zero;
      for (final each in NeuronPhase.values) {
        if (each == phase) return cursor;
        cursor += neuronPhaseDurations[each]!;
      }

      return cursor;
    }

    test('las guias entran durante guides, con la polaridad invertida', () {
      // En las capas de este package, `progress` en 0 pinta la capa completa
      // y en 1 no
      // pinta nada: una capa entra llevandolo de 1 a 0.
      expect(timeline.frameAt(Duration.zero).guides, 1);
      expect(
        timeline
            .frameAt(
              startOf(NeuronPhase.dots) - const Duration(milliseconds: 60),
            )
            .guides,
        closeTo(0.5, 0.01),
      );
      expect(timeline.frameAt(startOf(NeuronPhase.dots)).guides, 0);
    });

    test('las guias se van durante settle, y son las ultimas', () {
      expect(timeline.frameAt(startOf(NeuronPhase.settle)).guides, 0);
      expect(
        timeline
            .frameAt(
              startOf(NeuronPhase.settle) + const Duration(milliseconds: 60),
            )
            .guides,
        closeTo(0.5, 0.01),
      );
      expect(timeline.frameAt(timeline.total).guides, 1);
    });

    test('los puntos entran en dots y se van en condense', () {
      expect(timeline.frameAt(startOf(NeuronPhase.dots)).dots, 1);
      expect(timeline.frameAt(startOf(NeuronPhase.noise)).dots, 0);
      expect(timeline.frameAt(startOf(NeuronPhase.chromatic)).dots, 1);
    });

    test('el ruido entra en noise y se va en condense', () {
      expect(timeline.frameAt(startOf(NeuronPhase.noise)).noise, 1);
      expect(timeline.frameAt(startOf(NeuronPhase.condense)).noise, 0);
      expect(timeline.frameAt(startOf(NeuronPhase.chromatic)).noise, 1);
    });

    test('el contenido aparece durante condense', () {
      expect(timeline.frameAt(startOf(NeuronPhase.condense)).content, 0);
      expect(
        timeline
            .frameAt(
              startOf(NeuronPhase.condense) + const Duration(milliseconds: 90),
            )
            .content,
        closeTo(0.5, 0.01),
      );
      expect(timeline.frameAt(startOf(NeuronPhase.chromatic)).content, 1);
    });

    test('una capa sin su fase de entrada no se pinta nunca', () {
      final sinPuntos = NeuronTimeline(
        phases: const [
          NeuronPhase.guides,
          NeuronPhase.noise,
          NeuronPhase.condense,
          NeuronPhase.settle,
        ],
      );

      expect(sinPuntos.frameAt(Duration.zero).dots, 1);
      expect(sinPuntos.frameAt(sinPuntos.total).dots, 1);
    });

    test('una capa sin su fase de salida vive hasta el final', () {
      final sinCondense = NeuronTimeline(
        phases: const [
          NeuronPhase.guides,
          NeuronPhase.dots,
          NeuronPhase.noise,
          NeuronPhase.settle,
        ],
      );
      // El arranque de `settle`, que es cuando las dos capas ya terminaron de
      // entrar: un instante antes, el ruido todavia esta entrando.
      final formadas =
          sinCondense.total - neuronPhaseDurations[NeuronPhase.settle]!;

      expect(sinCondense.frameAt(formadas).dots, 0);
      expect(sinCondense.frameAt(formadas).noise, 0);
      // Y siguen puestas hasta el ultimo instante.
      expect(
        sinCondense
            .frameAt(sinCondense.total - const Duration(milliseconds: 1))
            .dots,
        0,
      );
    });

    test('sin condense el contenido esta visible desde el primer frame', () {
      final sinCondense = NeuronTimeline(
        phases: const [NeuronPhase.guides, NeuronPhase.settle],
      );

      expect(sinCondense.frameAt(Duration.zero).content, 1);
    });

    test('pasado el total no hay fase activa', () {
      expect(timeline.frameAt(timeline.total).phase, isNull);
      expect(
        timeline.frameAt(timeline.total + const Duration(seconds: 1)).phase,
        isNull,
      );
    });

    test('la fase activa recorre las siete en orden', () {
      final vistas = <NeuronPhase>[
        for (final phase in NeuronPhase.values)
          timeline.frameAt(startOf(phase)).phase!,
      ];

      expect(vistas, NeuronPhase.values);
    });
  });

  group('NeuronTimeline, el punto de espera', () {
    test('es el arranque de condense cuando condense esta', () {
      final timeline = NeuronTimeline(phases: NeuronPhase.values);
      final formacion =
          neuronPhaseDurations[NeuronPhase.guides]! +
          neuronPhaseDurations[NeuronPhase.dots]! +
          neuronPhaseDurations[NeuronPhase.noise]!;

      expect(
        timeline.holdPoint,
        closeTo(
          formacion.inMicroseconds / timeline.total.inMicroseconds,
          0.0001,
        ),
      );
    });

    test('sin condense es el arranque de la primera fase de resolucion', () {
      final timeline = NeuronTimeline(
        phases: const [NeuronPhase.guides, NeuronPhase.slice],
      );

      expect(
        timeline.holdPoint,
        closeTo(
          neuronPhaseDurations[NeuronPhase.guides]!.inMicroseconds /
              timeline.total.inMicroseconds,
          0.0001,
        ),
      );
    });

    test('sin ninguna fase de resolucion se espera al final', () {
      final timeline = NeuronTimeline(
        phases: const [NeuronPhase.guides, NeuronPhase.dots],
      );

      expect(timeline.holdPoint, 1);
    });
  });
}
