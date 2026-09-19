import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Canvas falso que registra las lineas dibujadas.
///
/// Mismo idioma que `hold_progress_border_painter_test.dart`: se llama a
/// `paint` directo y se afirma sobre las operaciones, sin montar widget.
class _RecordingCanvas extends Fake implements Canvas {
  final List<(Offset, Offset)> lines = <(Offset, Offset)>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add((p1, p2));
}

void main() {
  const size = Size(90, 128);

  _RecordingCanvas paintWith({double bracketLength = 12}) {
    final canvas = _RecordingCanvas();

    TechFramePainter(
      bracketLength: bracketLength,
      strokeWidth: 1,
      color: const Color(0xFFFFFFFF),
      cornerOffsets: <Offset>[],
    ).paint(canvas, size);

    return canvas;
  }

  group('TechFramePainter', () {
    test('dibuja dos segmentos por esquina, ocho en total', () {
      expect(paintWith().lines, hasLength(8));
    });

    test('la esquina superior izquierda arranca en el origen', () {
      final lines = paintWith().lines;

      expect(lines, contains((Offset.zero, const Offset(12, 0))));
      expect(lines, contains((Offset.zero, const Offset(0, 12))));
    });

    test('la esquina inferior derecha cierra en el extremo opuesto', () {
      final lines = paintWith().lines;

      expect(lines, contains((const Offset(78, 128), const Offset(90, 128))));
      expect(lines, contains((const Offset(90, 116), const Offset(90, 128))));
    });

    test('el corchete no pasa de la mitad del lado corto: en una caja de 12 de '
        'alto, los dos verticales de un lado se tocarian', () {
      // 12 de alto y corchete de 12 daria dos segmentos de 12 sobre un lado
      // de 12: el de arriba y el de abajo se encontrarian en el medio y el
      // marco se leeria como un rectangulo cerrado.
      final canvas = _RecordingCanvas();

      const TechFramePainter(
        bracketLength: 12,
        strokeWidth: 1,
        color: Color(0xFFFFFFFF),
        cornerOffsets: <Offset>[],
      ).paint(canvas, const Size(180, 12));

      expect(canvas.lines, contains((Offset.zero, const Offset(0, 6))));
    });
  });

  group('TechFrame', () {
    testWidgets('pinta por delante del hijo, no por detras', (tester) async {
      await tester.pumpWidget(
        const TechFrame(child: SizedBox(width: 90, height: 128)),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).first,
      );

      expect(customPaint.foregroundPainter, isA<TechFramePainter>());
      expect(customPaint.painter, isNull);
    });
  });

  group('TechFramePainter.shouldRepaint', () {
    const base = TechFramePainter(
      bracketLength: 12,
      strokeWidth: 1,
      color: Color(0xFFFFFFFF),
      cornerOffsets: <Offset>[],
    );

    test('repinta cuando cambia el largo del corchete', () {
      expect(
        const TechFramePainter(
          bracketLength: 20,
          strokeWidth: 1,
          color: Color(0xFFFFFFFF),
          cornerOffsets: <Offset>[],
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el ancho del trazo', () {
      expect(
        const TechFramePainter(
          bracketLength: 12,
          strokeWidth: 2,
          color: Color(0xFFFFFFFF),
          cornerOffsets: <Offset>[],
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el color', () {
      expect(
        const TechFramePainter(
          bracketLength: 12,
          strokeWidth: 1,
          color: Color(0xFF000000),
          cornerOffsets: <Offset>[],
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('no repinta con los mismos campos', () {
      expect(base.shouldRepaint(base), isFalse);
    });
  });

  testWidgets('acepta los parametros calculados en runtime, sin const', (
    tester,
  ) async {
    // El caso real de un consumidor: los corrimientos de las esquinas salen de
    // un widget que los anima, asi que no hay contexto `const` en ningun lado.
    // Los demas tests construyen con `const` y esa forma se evalua en
    // compilacion, que deja el constructor sin ejercitar.
    final offsets = List<Offset>.generate(4, (i) => Offset(i.toDouble(), 0));

    await tester.pumpWidget(
      MaterialApp(
        home: TechFrame(
          bracketLength: 8 + offsets.length.toDouble(),
          cornerOffsets: offsets,
          child: const SizedBox(width: 90, height: 128),
        ),
      ),
    );

    final frame = tester.widget<TechFrame>(find.byType(TechFrame));

    expect(frame.bracketLength, 12);
    expect(frame.cornerOffsets, hasLength(4));
  });
}
