import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  group('neuronSweepPeriod =>', () {
    test('dos semillas distintas dan períodos distintos', () {
      // `NoiseSweep` arranca su reloj en 0 y no desfasa por semilla: veinte
      // cajas montadas en el mismo frame laten en fase, que lee como parpadeo
      // y no como carga.
      expect(neuronSweepPeriod(0), isNot(neuronSweepPeriod(1)));
    });

    test('la misma semilla da siempre el mismo período', () {
      expect(neuronSweepPeriod(5), neuronSweepPeriod(5));
    });

    test('el período cae en el rango de la fórmula', () {
      for (var seed = 0; seed < 32; seed++) {
        final period = neuronSweepPeriod(seed);

        expect(period.inMilliseconds, greaterThanOrEqualTo(2800));
        expect(period.inMilliseconds, lessThanOrEqualTo(3430));
      }
    });

    test('una semilla negativa sigue dando un período del rango', () {
      // El `%` de Dart sobre enteros devuelve siempre un valor no negativo.
      expect(neuronSweepPeriod(-3).inMilliseconds, greaterThanOrEqualTo(2800));
    });

    test('es más rápido que la deriva de las guías', () {
      // El invariante que justifica que la fórmula viva acá y no en el
      // esqueleto que la usa: las guías más lentas que el barrido.
      for (var seed = 0; seed < 32; seed++) {
        expect(
          neuronSweepPeriod(seed).inMilliseconds,
          lessThan(neuronGuideDriftPeriod(seed).inMilliseconds),
        );
      }
    });
  });
}
