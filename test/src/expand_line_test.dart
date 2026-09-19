import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Registra los rectangulos que le dibujan, como el `_RecordingCanvas` que
/// usan los tests de las capas.
class _RecordingCanvas extends Fake implements Canvas {
  final List<(Rect, Color)> rects = <(Rect, Color)>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add((rect, paint.color));
}

/// Monta [child] adentro de un `MediaQuery`, que es lo que el gate de
/// reduce-motion consulta.
Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Align(alignment: Alignment.topLeft, child: child),
);

/// Avanza [frames] frames de 16 ms, como corre la app.
Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// El painter de la linea del [ExpandLine] montado.
ExpandLinePainter _painterOf(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(ExpandLine),
                matching: find.byType(CustomPaint),
              ),
            )
            .foregroundPainter!
        as ExpandLinePainter;

void main() {
  const child = SizedBox(width: 200, height: 100);

  group('ExpandLinePainter', () {
    test('con alignment centrado, la linea va al medio de la caja', () {
      final canvas = _RecordingCanvas();

      const ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 2,
        alignment: Alignment.center,
        opacity: 1,
      ).paint(canvas, const Size(200, 100));

      expect(canvas.rects, hasLength(1));
      expect(canvas.rects.single.$1, const Rect.fromLTWH(0, 49, 200, 2));
    });

    test('con alignment arriba, la linea va al borde superior', () {
      final canvas = _RecordingCanvas();

      const ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 2,
        alignment: Alignment.topCenter,
        opacity: 1,
      ).paint(canvas, const Size(200, 100));

      expect(canvas.rects.single.$1, const Rect.fromLTWH(0, 0, 200, 2));
    });

    test('con alignment abajo, la linea va al borde inferior', () {
      final canvas = _RecordingCanvas();

      const ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 2,
        alignment: Alignment.bottomCenter,
        opacity: 1,
      ).paint(canvas, const Size(200, 100));

      expect(canvas.rects.single.$1, const Rect.fromLTWH(0, 98, 200, 2));
    });

    test('la opacidad escala el alpha del color', () {
      final canvas = _RecordingCanvas();

      const ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 1,
        alignment: Alignment.center,
        opacity: 0.5,
      ).paint(canvas, const Size(200, 100));

      expect(canvas.rects.single.$2.a, closeTo(0.5, 0.01));
    });

    test('con opacidad en 0 no dibuja nada', () {
      final canvas = _RecordingCanvas();

      const ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 1,
        alignment: Alignment.center,
        opacity: 0,
      ).paint(canvas, const Size(200, 100));

      expect(canvas.rects, isEmpty);
    });

    test('con lineHeight en 0 no dibuja nada', () {
      final canvas = _RecordingCanvas();

      const ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 0,
        alignment: Alignment.center,
        opacity: 1,
      ).paint(canvas, const Size(200, 100));

      expect(canvas.rects, isEmpty);
    });

    test('con una caja vacia no dibuja nada', () {
      final canvas = _RecordingCanvas();

      const ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 1,
        alignment: Alignment.center,
        opacity: 1,
      ).paint(canvas, Size.zero);

      expect(canvas.rects, isEmpty);
    });

    test('shouldRepaint mira los cuatro campos', () {
      const painter = ExpandLinePainter(
        color: Color(0xFFFFFFFF),
        lineHeight: 1,
        alignment: Alignment.center,
        opacity: 1,
      );

      expect(painter.shouldRepaint(painter), isFalse);
      expect(
        painter.shouldRepaint(
          const ExpandLinePainter(
            color: Color(0xFF000000),
            lineHeight: 1,
            alignment: Alignment.center,
            opacity: 1,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const ExpandLinePainter(
            color: Color(0xFFFFFFFF),
            lineHeight: 2,
            alignment: Alignment.center,
            opacity: 1,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const ExpandLinePainter(
            color: Color(0xFFFFFFFF),
            lineHeight: 1,
            alignment: Alignment.topCenter,
            opacity: 1,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const ExpandLinePainter(
            color: Color(0xFFFFFFFF),
            lineHeight: 1,
            alignment: Alignment.center,
            opacity: 0.5,
          ),
        ),
        isTrue,
      );
    });
  });

  group('ExpandLine', () {
    testWidgets('durante lineHold la caja mide lineHeight y nada mas', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ExpandLine(lineHeight: 3, child: child)),
      );
      // Warm-up: el primer tick del Ticker reporta elapsed 0.
      await tester.pump();
      // 48 ms de los 80 de lineHold.
      await _pumpFrames(tester, 3);

      expect(tester.getSize(find.byType(ExpandLine)).height, 3);
      // El ancho no cambia: lo que se recorta es el alto.
      expect(tester.getSize(find.byType(ExpandLine)).width, 200);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('pasado el hold, el alto crece hasta el del hijo', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const ExpandLine(child: child)));
      await tester.pump();
      // 80 ms de hold mas la mitad de los 280 de apertura.
      await _pumpFrames(tester, 14);

      final medio = tester.getSize(find.byType(ExpandLine)).height;

      expect(medio, greaterThan(1));
      expect(medio, lessThan(100));

      // Y el resto de la apertura, mas un frame por el `isDone` estricto.
      await _pumpFrames(tester, 14);

      expect(tester.getSize(find.byType(ExpandLine)).height, 100);
    });

    testWidgets('la linea se desvanece a medida que la caja crece', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const ExpandLine(child: child)));
      await tester.pump();
      await _pumpFrames(tester, 3);

      expect(_painterOf(tester).opacity, 1);

      await _pumpFrames(tester, 14);

      expect(_painterOf(tester).opacity, lessThan(1));

      await _pumpFrames(tester, 14);

      expect(_painterOf(tester).opacity, 0);
    });

    testWidgets('la curva cambia el alto intermedio', (tester) async {
      Future<double> altoAlaMitad(Curve curve) async {
        await tester.pumpWidget(_host(ExpandLine(curve: curve, child: child)));
        await tester.pump();
        await _pumpFrames(tester, 14);

        final alto = tester.getSize(find.byType(ExpandLine)).height;

        await tester.pumpWidget(_host(const SizedBox()));

        return alto;
      }

      expect(
        await altoAlaMitad(Curves.easeOutCubic),
        isNot(await altoAlaMitad(Curves.linear)),
      );
    });

    testWidgets('con duraciones en cero el hijo esta entero de una', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ExpandLine(
            duration: Duration.zero,
            lineHold: Duration.zero,
            child: child,
          ),
        ),
      );

      expect(tester.getSize(find.byType(ExpandLine)).height, 100);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('un lineHeight negativo no rompe el layout', (tester) async {
      await tester.pumpWidget(
        _host(const ExpandLine(lineHeight: -1, child: child)),
      );
      await tester.pump();

      // `BoxConstraints` lanza en el layout con un `minHeight` negativo, y el
      // painter ya trata al valor como una linea vacia: el piso se recorta a 0
      // y el panel arranca sin alto, no roto.
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ExpandLine)).height, 0);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('un lineHold negativo no abre el panel a medias', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ExpandLine(lineHold: Duration(milliseconds: -80), child: child),
        ),
      );
      await tester.pump();

      // Sin recortar la fraccion, el primer frame arrancaria con el panel ya
      // abierto en parte y sin linea.
      expect(tester.getSize(find.byType(ExpandLine)).height, 1);
      expect(_painterOf(tester).opacity, 1);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets(
      'con reducir movimiento el hijo esta entero, sin linea y sin ticker',
      (tester) async {
        await tester.pumpWidget(
          _host(const ExpandLine(child: child), reduceMotion: true),
        );

        expect(tester.getSize(find.byType(ExpandLine)).height, 100);
        expect(tester.binding.transientCallbackCount, 0);
        expect(_painterOf(tester).opacity, 0);

        await tester.pumpWidget(_host(const SizedBox()));
      },
    );

    testWidgets('cambiar la duracion en vivo reinicia la apertura', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const ExpandLine(child: child)));
      await tester.pump();
      await _pumpFrames(tester, 28);

      expect(tester.getSize(find.byType(ExpandLine)).height, 100);

      await tester.pumpWidget(
        _host(const ExpandLine(duration: Duration(seconds: 1), child: child)),
      );
      await tester.pump();

      // El gate vive en un `_apply` que llama tambien `didUpdateWidget`: sin
      // eso, un cambio de parametro no lo alcanzaria nunca.
      expect(tester.getSize(find.byType(ExpandLine)).height, 1);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('un rebuild que no toca las duraciones no la reinicia', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const ExpandLine(child: child)));
      await tester.pump();
      await _pumpFrames(tester, 14);

      final medio = tester.getSize(find.byType(ExpandLine)).height;

      // Cualquier rebuild del padre pasa por aca: si `didUpdateWidget` no
      // saliera temprano, la apertura volveria a arrancar de cero.
      await tester.pumpWidget(
        _host(const ExpandLine(lineColor: Color(0xFF00FF00), child: child)),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(ExpandLine)).height,
        greaterThanOrEqualTo(medio),
      );

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('adentro de un Stagger, la apertura espera su turno', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Stagger(index: 2, child: ExpandLine(child: child))),
      );
      await tester.pump();
      // 256 ms: los 180 de espera del tercer hermano mas 76 de los 80 del
      // hold, asi que todavia es la linea sola. Sin el retraso ya estaria
      // abriendo.
      await _pumpFrames(tester, 16);

      expect(tester.getSize(find.byType(ExpandLine)).height, 1);

      // Cumplido el retraso, arranca.
      await _pumpFrames(tester, 12);

      expect(tester.getSize(find.byType(ExpandLine)).height, greaterThan(1));

      await tester.pumpWidget(_host(const SizedBox()));
    });
  });
}
