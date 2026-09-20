import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Monta [stagger] y devuelve el retraso que ve un descendiente.
///
/// El `Builder` es lo que da un `BuildContext` **abajo** del scope: leerlo desde
/// el contexto del propio `Stagger` no encontraria nada.
Future<Duration> _delayUnder(
  WidgetTester tester,
  Stagger Function(Widget child) stagger, {
  bool reduceMotion = false,
}) async {
  var captured = const Duration(days: 1);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: stagger(
        Builder(
          builder: (context) {
            captured = Stagger.delayOf(context);

            return const SizedBox();
          },
        ),
      ),
    ),
  );

  return captured;
}

void main() {
  const step = Duration(milliseconds: 90);

  group('Stagger', () {
    testWidgets('el primer hermano no espera nada', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(index: 0, child: child),
      );

      expect(delay, Duration.zero);
    });

    testWidgets('el hermano n espera n * step', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(index: 3, child: child),
      );

      expect(delay, step * 3);
    });

    testWidgets('el retraso se satura en maxDelay', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(index: 40, child: child),
      );

      // Sin tope, el item 40 de un ListView.builder esperaria 3,6 segundos
      // antes de empezar a existir.
      expect(delay, const Duration(milliseconds: 450));
    });

    testWidgets('reverse cuenta desde el final', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(
          index: 0,
          count: 5,
          order: StaggerOrder.reverse,
          child: child,
        ),
      );

      expect(delay, step * 4);
    });

    testWidgets('random usa la permutacion de la semilla', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(
          index: 1,
          count: 5,
          order: StaggerOrder.random,
          seed: 7,
          child: child,
        ),
      );

      // La posicion se deriva de la implementacion, no de correr y copiar el
      // numero que salio: es la misma permutacion que arma el widget.
      final expected = [for (var i = 0; i < 5; i++) i]..shuffle(math.Random(7));

      expect(delay, step * expected[1]);
    });

    testWidgets('forward da lo mismo con count y sin el', (tester) async {
      // El call site real pasa el count —lo necesitan los otros dos ordenes— y
      // forward tiene que ignorarlo.
      final conCount = await _delayUnder(
        tester,
        (child) => Stagger(index: 2, count: 5, child: child),
      );
      final sinCount = await _delayUnder(
        tester,
        (child) => Stagger(index: 2, child: child),
      );

      expect(conCount, step * 2);
      expect(sinCount, step * 2);
    });

    testWidgets(
      'un count que no cubre al index degrada a forward en vez de dar una '
      'posicion negativa',
      (tester) async {
        final delay = await _delayUnder(
          tester,
          (child) => Stagger(
            index: 4,
            count: 2,
            order: StaggerOrder.reverse,
            maxDelay: const Duration(seconds: 10),
            child: child,
          ),
        );

        // Con reverse seria 2 - 1 - 4 = -3.
        expect(delay, step * 4);
      },
    );

    testWidgets('un index negativo no espera', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(
          index: -2,
          count: 5,
          order: StaggerOrder.random,
          child: child,
        ),
      );

      expect(delay, Duration.zero);
    });

    testWidgets('con jitter dos semillas dan retrasos distintos', (
      tester,
    ) async {
      final uno = await _delayUnder(
        tester,
        (child) => Stagger(index: 2, jitter: 0.5, child: child),
      );
      final otro = await _delayUnder(
        tester,
        (child) => Stagger(index: 2, jitter: 0.5, seed: 99, child: child),
      );

      expect(uno, isNot(otro));
      // Y los dos caen adentro del rango que promete jitter: 0,5 sobre el step
      // deja el retraso entre la mitad y una vez y media.
      for (final delay in [uno, otro]) {
        expect(delay, greaterThanOrEqualTo(step * 1));
        expect(delay, lessThanOrEqualTo(step * 3));
      }
    });

    testWidgets('con jitter en 0 el retraso es exacto', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(index: 2, seed: 99, child: child),
      );

      expect(delay, step * 2);
    });

    testWidgets('con reducir movimiento nadie espera', (tester) async {
      final delay = await _delayUnder(
        tester,
        (child) => Stagger(index: 3, child: child),
        reduceMotion: true,
      );

      expect(delay, Duration.zero);
    });

    testWidgets('sin Stagger arriba, delayOf devuelve cero', (tester) async {
      var captured = const Duration(days: 1);

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = Stagger.delayOf(context);

            return const SizedBox();
          },
        ),
      );

      expect(captured, Duration.zero);
    });

    testWidgets('cambiar el retraso notifica a los descendientes', (
      tester,
    ) async {
      final vistos = <Duration>[];

      Widget build(int index) => Stagger(
        index: index,
        child: Builder(
          builder: (context) {
            vistos.add(Stagger.delayOf(context));

            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(build(1));
      await tester.pumpWidget(build(2));

      expect(vistos, [step * 1, step * 2]);
    });
  });
}
