import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Canvas falso que registra los circulos dibujados.
class _RecordingCanvas extends Fake implements Canvas {
  final List<Offset> centers = <Offset>[];
  final List<Paint> paints = <Paint>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    centers.add(c);
    paints.add(paint);
  }
}

void main() {
  const size = Size(40, 40);

  _RecordingCanvas paintWith({double? progress, double spacing = 8}) {
    final canvas = _RecordingCanvas();

    DotMatrixPainter(
      spacing: spacing,
      dotRadius: 0.75,
      color: const Color(0x33FFFFFF),
      progress: progress,
    ).paint(canvas, size);

    return canvas;
  }

  group('DotMatrixPainter', () {
    test('la matriz es regular: 5 por 5 con spacing 8 en 40 por 40', () {
      expect(paintWith().centers, hasLength(25));
    });

    test('el primer punto queda a medio spacing del origen', () {
      expect(paintWith().centers.first, const Offset(4, 4));
    });

    test('sin progress pinta la matriz completa y sin atenuar', () {
      final canvas = paintWith();

      expect(canvas.paints.first.color.a, closeTo(0.2, 0.01));
    });

    test('con progress 1 no pinta ningun punto: la capa es transitoria', () {
      expect(paintWith(progress: 1).centers, isEmpty);
    });

    test('con spacing 0 no pinta nada en vez de colgar el hilo de UI', () {
      // El loop avanza `y` de a `spacing`: con 0 nunca sale, y con negativo
      // retrocede. Es un parametro publico sin validar, asi que la guarda va
      // en el painter y no en un assert, que en release no existe.
      expect(paintWith(spacing: 0).centers, isEmpty);
    });

    test('con progress 0.5 la matriz se atenua a la mitad', () {
      final canvas = paintWith(progress: 0.5);

      expect(canvas.centers, hasLength(25));
      expect(canvas.paints.first.color.a, closeTo(0.1, 0.01));
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

  group('DotMatrix', () {
    testWidgets('pinta por delante del hijo', (tester) async {
      await tester.pumpWidget(
        const DotMatrix(child: SizedBox(width: 40, height: 40)),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).first,
      );

      expect(customPaint.foregroundPainter, isA<DotMatrixPainter>());
    });
  });

  group('DotMatrixPainter.shouldRepaint', () {
    const base = DotMatrixPainter(
      spacing: 8,
      dotRadius: 0.75,
      color: Color(0x33FFFFFF),
      progress: null,
    );

    test('repinta cuando cambia el progreso', () {
      expect(
        const DotMatrixPainter(
          spacing: 8,
          dotRadius: 0.75,
          color: Color(0x33FFFFFF),
          progress: 0.5,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el spacing', () {
      expect(
        const DotMatrixPainter(
          spacing: 16,
          dotRadius: 0.75,
          color: Color(0x33FFFFFF),
          progress: null,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el radio del punto', () {
      expect(
        const DotMatrixPainter(
          spacing: 8,
          dotRadius: 1.5,
          color: Color(0x33FFFFFF),
          progress: null,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el color', () {
      expect(
        const DotMatrixPainter(
          spacing: 8,
          dotRadius: 0.75,
          color: Color(0xFFFFFFFF),
          progress: null,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('no repinta con los mismos campos', () {
      expect(base.shouldRepaint(base), isFalse);
    });
  });
}
