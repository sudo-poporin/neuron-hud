import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Canvas falso que registra los rectangulos dibujados.
class _RecordingCanvas extends Fake implements Canvas {
  final List<Rect> rects = <Rect>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);
}

void main() {
  const size = Size(90, 128);

  _RecordingCanvas paintWith({double? progress, int seed = 42}) {
    final canvas = _RecordingCanvas();

    BlockNoisePainter(
      density: 0.35,
      color: const Color(0xFFFFFFFF),
      barHeight: 2,
      minBarWidth: 4,
      maxBarWidth: 48,
      progress: progress,
      seed: seed,
    ).paint(canvas, size);

    return canvas;
  }

  group('BlockNoisePainter', () {
    test('sin progress pinta barras', () {
      expect(paintWith().rects, isNotEmpty);
    });

    test('con progress 1 no pinta ninguna barra', () {
      expect(paintWith(progress: 1).rects, isEmpty);
    });

    test('la misma semilla da el mismo layout', () {
      expect(paintWith().rects, equals(paintWith().rects));
    });

    test('semillas distintas dan layouts distintos', () {
      expect(paintWith(seed: 1).rects, isNot(equals(paintWith(seed: 2).rects)));
    });

    test('las barras que sobreviven al progreso no se mueven: el layout es un '
        'prefijo fijo, no una tirada nueva', () {
      // Es lo que muestran los cuatro frames de la referencia: cambia la
      // cantidad de barras, no su forma ni su posicion.
      final full = paintWith().rects;
      final half = paintWith(progress: 0.5).rects;

      expect(half, hasLength(lessThan(full.length)));
      expect(full.take(half.length).toList(), equals(half));
    });

    test('todas las barras caen dentro de la caja', () {
      for (final rect in paintWith().rects) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
    });

    test('cada barra tiene el alto configurado', () {
      for (final rect in paintWith().rects) {
        expect(rect.height, closeTo(2, 1e-10));
      }
    });

    test('una caja de area cero no pinta nada', () {
      final canvas = _RecordingCanvas();

      const BlockNoisePainter(
        density: 0.35,
        color: Color(0xFFFFFFFF),
        barHeight: 2,
        minBarWidth: 4,
        maxBarWidth: 48,
        progress: null,
        seed: 42,
      ).paint(canvas, Size.zero);

      expect(canvas.rects, isEmpty);
    });

    test('un progress negativo se comporta igual que 0', () {
      // El contrato dice que 0 pinta la capa completa, asi que ese es el
      // techo: un valor negativo no puede pintar mas. `remaining` esta
      // clampeado justamente para eso.
      expect(paintWith(progress: -0.5).rects, equals(paintWith().rects));
    });

    test('una barra mas alta que la caja no se sale por abajo', () {
      // El ancho ya estaba acotado; el alto no lo estaba, y una barra de 40
      // sobre una caja de 128 de alto todavia entra, pero una de 200 no.
      final canvas = _RecordingCanvas();

      const BlockNoisePainter(
        density: 0.35,
        color: Color(0xFFFFFFFF),
        barHeight: 200,
        minBarWidth: 4,
        maxBarWidth: 48,
        progress: null,
        seed: 42,
      ).paint(canvas, size);

      for (final rect in canvas.rects) {
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
    });
  });

  group('BlockNoise', () {
    testWidgets('pinta por delante del hijo', (tester) async {
      await tester.pumpWidget(
        const BlockNoise(child: SizedBox(width: 90, height: 128)),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).first,
      );

      expect(customPaint.foregroundPainter, isA<BlockNoisePainter>());
    });
  });

  group('BlockNoisePainter.shouldRepaint', () {
    const base = BlockNoisePainter(
      density: 0.35,
      color: Color(0xFFFFFFFF),
      barHeight: 2,
      minBarWidth: 4,
      maxBarWidth: 48,
      progress: null,
      seed: 42,
    );

    test('repinta cuando cambia la semilla', () {
      expect(
        const BlockNoisePainter(
          density: 0.35,
          color: Color(0xFFFFFFFF),
          barHeight: 2,
          minBarWidth: 4,
          maxBarWidth: 48,
          progress: null,
          seed: 7,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la densidad', () {
      expect(
        const BlockNoisePainter(
          density: 0.5,
          color: Color(0xFFFFFFFF),
          barHeight: 2,
          minBarWidth: 4,
          maxBarWidth: 48,
          progress: null,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el color', () {
      expect(
        const BlockNoisePainter(
          density: 0.35,
          color: Color(0xFF000000),
          barHeight: 2,
          minBarWidth: 4,
          maxBarWidth: 48,
          progress: null,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el alto de barra', () {
      expect(
        const BlockNoisePainter(
          density: 0.35,
          color: Color(0xFFFFFFFF),
          barHeight: 4,
          minBarWidth: 4,
          maxBarWidth: 48,
          progress: null,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el ancho minimo', () {
      expect(
        const BlockNoisePainter(
          density: 0.35,
          color: Color(0xFFFFFFFF),
          barHeight: 2,
          minBarWidth: 8,
          maxBarWidth: 48,
          progress: null,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el ancho maximo', () {
      expect(
        const BlockNoisePainter(
          density: 0.35,
          color: Color(0xFFFFFFFF),
          barHeight: 2,
          minBarWidth: 4,
          maxBarWidth: 64,
          progress: null,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el progreso', () {
      expect(
        const BlockNoisePainter(
          density: 0.35,
          color: Color(0xFFFFFFFF),
          barHeight: 2,
          minBarWidth: 4,
          maxBarWidth: 48,
          progress: 0.5,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('no repinta con los mismos campos', () {
      expect(base.shouldRepaint(base), isFalse);
    });
  });
}
