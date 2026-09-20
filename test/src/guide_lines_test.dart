import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Canvas falso que registra las lineas dibujadas y con que se dibujaron.
class _RecordingCanvas extends Fake implements Canvas {
  final List<(Offset, Offset)> lines = <(Offset, Offset)>[];
  final List<Paint> paints = <Paint>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add((p1, p2));
    paints.add(paint);
  }
}

void main() {
  const size = Size(90, 128);

  _RecordingCanvas paintWith({
    double? progress,
    int verticals = 2,
    int horizontals = 0,
    int tickCount = 3,
    double overflow = 0,
    double drift = 0,
    int seed = 42,
  }) {
    final canvas = _RecordingCanvas();

    GuideLinesPainter(
      verticals: verticals,
      horizontals: horizontals,
      tickCount: tickCount,
      tickLength: 4,
      strokeWidth: 1,
      color: const Color(0x66FFFFFF),
      overflow: overflow,
      progress: progress,
      drift: drift,
      seed: seed,
    ).paint(canvas, size);

    return canvas;
  }

  group('GuideLinesPainter', () {
    test('dos verticales con tres ticks cada una son ocho lineas', () {
      // 2 verticales + 2 * 3 ticks = 8
      expect(paintWith().lines, hasLength(8));
    });

    test('sin horizontales ninguna linea abarca el ancho de la caja', () {
      // Una horizontal va de borde a borde en X; una vertical y sus ticks no.
      // Es lo que las distingue sin depender del orden de dibujado.
      for (final line in paintWith().lines) {
        expect((line.$2.dx - line.$1.dx).abs(), lessThan(size.width));
      }
    });

    test('agrega las horizontales cuando se piden', () {
      // 2 verticales * (1 + 3) + 1 horizontal * (1 + 3) = 12
      expect(paintWith(horizontals: 1).lines, hasLength(12));
    });

    test('con progress 1 no dibuja nada: el andamio tambien se va', () {
      expect(paintWith(progress: 1).lines, isEmpty);
    });

    test('la misma semilla da las mismas posiciones', () {
      expect(paintWith().lines, equals(paintWith().lines));
    });

    test('semillas distintas dan layouts distintos', () {
      expect(paintWith(seed: 1).lines, isNot(equals(paintWith(seed: 2).lines)));
    });

    test('sin overflow la vertical va de borde a borde de la caja', () {
      final vertical = paintWith().lines.first;

      expect(vertical.$1.dy, 0);
      expect(vertical.$2.dy, size.height);
    });

    test('con overflow la vertical se sale de la caja por los dos lados', () {
      final vertical = paintWith(overflow: 20).lines.first;

      expect(vertical.$1.dy, -20);
      expect(vertical.$2.dy, size.height + 20);
    });

    test('sin ticks solo dibuja las lineas', () {
      expect(paintWith(tickCount: 0).lines, hasLength(2));
    });

    test('con progress 0.5 las guias se atenuan a la mitad', () {
      expect(paintWith(progress: 0.5).paints.first.color.a, closeTo(0.2, 0.01));
    });

    test('un progress negativo no pinta mas opaco que la capa completa', () {
      // El contrato dice que 0 pinta la capa completa, asi que ese es el
      // techo. `remaining` esta clampeado justamente para eso.
      expect(
        paintWith(progress: -0.5).paints.first.color.a,
        paintWith().paints.first.color.a,
      );
    });
  });

  group('GuideLines', () {
    testWidgets('pinta por delante del hijo', (tester) async {
      await tester.pumpWidget(
        const GuideLines(child: SizedBox(width: 90, height: 128)),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).first,
      );

      expect(customPaint.foregroundPainter, isA<GuideLinesPainter>());
    });
  });

  group('GuideLinesPainter.shouldRepaint', () {
    const base = GuideLinesPainter(
      verticals: 2,
      horizontals: 0,
      tickCount: 3,
      tickLength: 4,
      strokeWidth: 1,
      color: Color(0x66FFFFFF),
      overflow: 0,
      progress: null,
      drift: 0,
      seed: 42,
    );

    test('repinta cuando cambia el overflow', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 0,
          tickCount: 3,
          tickLength: 4,
          strokeWidth: 1,
          color: Color(0x66FFFFFF),
          overflow: 20,
          progress: null,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la cantidad de verticales', () {
      expect(
        const GuideLinesPainter(
          verticals: 4,
          horizontals: 0,
          tickCount: 3,
          tickLength: 4,
          strokeWidth: 1,
          color: Color(0x66FFFFFF),
          overflow: 0,
          progress: null,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la cantidad de horizontales', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 1,
          tickCount: 3,
          tickLength: 4,
          strokeWidth: 1,
          color: Color(0x66FFFFFF),
          overflow: 0,
          progress: null,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la cantidad de ticks', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 0,
          tickCount: 5,
          tickLength: 4,
          strokeWidth: 1,
          color: Color(0x66FFFFFF),
          overflow: 0,
          progress: null,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el largo del tick', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 0,
          tickCount: 3,
          tickLength: 8,
          strokeWidth: 1,
          color: Color(0x66FFFFFF),
          overflow: 0,
          progress: null,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el ancho del trazo', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 0,
          tickCount: 3,
          tickLength: 4,
          strokeWidth: 2,
          color: Color(0x66FFFFFF),
          overflow: 0,
          progress: null,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el color', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 0,
          tickCount: 3,
          tickLength: 4,
          strokeWidth: 1,
          color: Color(0xFFFFFFFF),
          overflow: 0,
          progress: null,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el progreso', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 0,
          tickCount: 3,
          tickLength: 4,
          strokeWidth: 1,
          color: Color(0x66FFFFFF),
          overflow: 0,
          progress: 0.5,
          drift: 0,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la semilla', () {
      expect(
        const GuideLinesPainter(
          verticals: 2,
          horizontals: 0,
          tickCount: 3,
          tickLength: 4,
          strokeWidth: 1,
          color: Color(0x66FFFFFF),
          overflow: 0,
          progress: null,
          drift: 0,
          seed: 7,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('no repinta con los mismos campos', () {
      expect(base.shouldRepaint(base), isFalse);
    });
  });
}
