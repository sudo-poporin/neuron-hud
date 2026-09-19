import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Canvas falso que registra las lineas dibujadas.
class _RecordingCanvas extends Fake implements Canvas {
  final List<(Offset, Offset)> lines = <(Offset, Offset)>[];
  final List<Paint> paints = <Paint>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add((p1, p2));
    paints.add(paint);
  }
}

/// Hijo de prueba, para contar sus copias en el arbol sin ambiguedad.
class _Marker extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 90, height: 128);
}

void main() {
  const size = Size(90, 128);

  group('SlicedStreaksPainter', () {
    _RecordingCanvas paintWith({
      List<({double top, double height})> bands = const [
        (top: 0.25, height: 0.1),
      ],
      double overflow = 24,
      double strokeWidth = 1,
      Size canvasSize = size,
    }) {
      final canvas = _RecordingCanvas();

      SlicedStreaksPainter(
        bands: bands,
        color: const Color(0xFFFFFFFF),
        overflow: overflow,
        strokeWidth: strokeWidth,
      ).paint(canvas, canvasSize);

      return canvas;
    }

    test('dibuja dos lineas por banda: el borde de arriba y el de abajo', () {
      expect(paintWith().lines, hasLength(2));
      expect(
        paintWith(
          bands: const [(top: 0.1, height: 0.1), (top: 0.6, height: 0.1)],
        ).lines,
        hasLength(4),
      );
    });

    test('las lineas caen en los bordes de la banda', () {
      final lines = paintWith().lines;

      expect(lines.first.$1.dy, closeTo(32, 1e-9));
      expect(lines.last.$1.dy, closeTo(44.8, 1e-9));
    });

    test('las lineas desbordan la caja a los dos lados', () {
      // Son los streaks largos hacia los lados de logo_animation.mp4: si un
      // ancestro clipea, el desborde se pierde.
      final line = paintWith().lines.first;

      expect(line.$1.dx, -24);
      expect(line.$2.dx, size.width + 24);
    });

    test('con overflow 0 las lineas no salen de la caja', () {
      final line = paintWith(overflow: 0).lines.first;

      expect(line.$1.dx, 0);
      expect(line.$2.dx, size.width);
    });

    test('el trazo usa el ancho pedido', () {
      expect(paintWith(strokeWidth: 3).paints.first.strokeWidth, 3);
    });

    test('sin bandas no dibuja nada', () {
      expect(paintWith(bands: const []).lines, isEmpty);
    });

    test('una caja de area cero no dibuja nada', () {
      expect(paintWith(canvasSize: Size.zero).lines, isEmpty);
    });
  });

  group('SlicedStreaksPainter.shouldRepaint', () {
    const base = SlicedStreaksPainter(
      bands: [(top: 0.25, height: 0.1)],
      color: Color(0xFFFFFFFF),
      overflow: 24,
      strokeWidth: 1,
    );

    test('repinta cuando cambian las bandas', () {
      expect(
        const SlicedStreaksPainter(
          bands: [(top: 0.5, height: 0.1)],
          color: Color(0xFFFFFFFF),
          overflow: 24,
          strokeWidth: 1,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el color', () {
      expect(
        const SlicedStreaksPainter(
          bands: [(top: 0.25, height: 0.1)],
          color: Color(0xFF000000),
          overflow: 24,
          strokeWidth: 1,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el desborde', () {
      expect(
        const SlicedStreaksPainter(
          bands: [(top: 0.25, height: 0.1)],
          color: Color(0xFFFFFFFF),
          overflow: 0,
          strokeWidth: 1,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el ancho de trazo', () {
      expect(
        const SlicedStreaksPainter(
          bands: [(top: 0.25, height: 0.1)],
          color: Color(0xFFFFFFFF),
          overflow: 24,
          strokeWidth: 4,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('no repinta con bandas de igual contenido', () {
      // listEquals y no identidad: el painter se arma de nuevo en cada frame.
      expect(
        const SlicedStreaksPainter(
          bands: [(top: 0.25, height: 0.1)],
          color: Color(0xFFFFFFFF),
          overflow: 24,
          strokeWidth: 1,
        ).shouldRepaint(base),
        isFalse,
      );
    });

    test('no absorbe el hit test', () {
      // `RenderCustomPaint.hitTestSelf` es `_painter!.hitTest(position) ?? true`:
      // un CustomPaint con `painter` absorbe los taps por default. El render
      // object de SlicedBox ya no monta ninguno, pero esta clase sigue siendo
      // publica y alguien puede montarla en uno. Sacar el `false` reintroduce
      // el defecto en la proxima persona que la use.
      expect(
        const SlicedStreaksPainter(
          bands: [(top: 0.25, height: 0.1)],
          color: Color(0xFFFFFFFF),
          overflow: 24,
          strokeWidth: 1,
        ).hitTest(Offset.zero),
        isFalse,
      );
    });
  });

  group('SlicedBox', () {
    Future<void> pumpSliced(
      WidgetTester tester, {
      bool disableAnimations = false,
      Duration? period,
      int sliceCount = 2,
      bool streaks = true,
      int seed = 42,
    }) {
      return tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Center(
            child: SlicedBox(
              period: period,
              sliceCount: sliceCount,
              streaks: streaks,
              seed: seed,
              child: const _Marker(),
            ),
          ),
        ),
      );
    }

    /// El render object que pinta las bandas.
    ///
    /// La pintura ya no deja rastro en el arbol, asi que el observable es el
    /// render object.
    RenderSlicedBox slicedOf(WidgetTester tester) =>
        tester.renderObject<RenderSlicedBox>(find.byType(SlicedBox));

    /// Los desplazamientos en X de las bandas, como los pinta el render object.
    List<double> bandShiftsOf(WidgetTester tester) {
      final render = slicedOf(tester);

      return [
        for (final slice in render.slices)
          slice.shift * render.sliceOffset * render.direction,
      ];
    }

    /// Las bandas que el render object recorta ahora mismo.
    List<Rect> bandsOf(WidgetTester tester) => [
      for (final slice in slicedOf(tester).slices)
        Rect.fromLTWH(
          0,
          slice.top * size.height,
          size.width,
          slice.height * size.height,
        ),
    ];

    testWidgets('el hijo entra al arbol una sola vez, en reposo y en rafaga', (
      tester,
    ) async {
      await pumpSliced(tester);

      expect(find.byType(_Marker), findsOneWidget);
      expect(slicedOf(tester).slices, isEmpty);

      // pump de warm-up: el primer tick del Ticker reporta elapsed 0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // La asercion titular: las bandas se pintan, no se insertan. El peor caso
      // de la app son 20 cajas simultaneas, y antes eran 60 subarboles.
      expect(slicedOf(tester).slices, hasLength(2));
      expect(find.byType(_Marker), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el hijo puede llevar un GlobalKey y la rafaga no lo rompe', (
      tester,
    ) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Center(
            child: SlicedBox(
              period: null,
              child: SizedBox(key: key, width: 90, height: 128),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(tester.takeException(), isNull);
      expect(key.currentContext, isNotNull);
      expect(slicedOf(tester).slices, isNotEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con un hijo que compone capa no pinta las bandas', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Center(
            child: SlicedBox(
              period: null,
              // 0,99 es visualmente identico a 1 pero deja el alpha en 252, y
              // RenderOpacity compone con cualquier alpha que no sea 0 ni 255.
              child: Opacity(opacity: 0.99, child: _Marker()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final render = slicedOf(tester);

      // La guarda se dispara y las bandas se saltean, aunque la rafaga corra.
      // Que el salteo efectivamente no pinte esta probado por pixeles en
      // `chromatic_burst_test.dart`: es exactamente la misma rama de codigo.
      expect(render.needsCompositing, isTrue);
      expect(render.slices, isNotEmpty);
      expect(tester.takeException(), isNull);

      // Los streaks quedan fuera de la guarda: no repintan al hijo, asi que un
      // hijo que compone pierde las bandas y conserva las lineas.
      expect(render.streaks, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('respeta un sliceCount propio', (tester) async {
      await pumpSliced(tester, sliceCount: 4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).slices, hasLength(4));
      expect(find.byType(_Marker), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con sliceCount 0 no corta nada', (tester) async {
      await pumpSliced(tester, sliceCount: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).slices, isEmpty);
    });

    testWidgets('con sliceCount negativo tampoco', (tester) async {
      await pumpSliced(tester, sliceCount: -3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).slices, isEmpty);
    });

    testWidgets('las bandas caen dentro de la caja', (tester) async {
      await pumpSliced(tester, sliceCount: 6);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      for (final rect in bandsOf(tester)) {
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height + 1e-9));
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el corrimiento se invierte entre subpasos de la rafaga', (
      tester,
    ) async {
      await pumpSliced(tester);
      await tester.pump();

      // Tres subpasos en 90 ms: 0-30, 30-60, 60-90.
      await tester.pump(const Duration(milliseconds: 15));
      final first = bandShiftsOf(tester);

      await tester.pump(const Duration(milliseconds: 30));
      final second = bandShiftsOf(tester);

      // Es lo que convierte un corrimiento estatico de 90 ms en un temblor, y
      // la razon de que haya ticker y no dos Timer.
      expect(first, hasLength(2));
      expect(second.first, closeTo(-first.first, 1e-9));
      expect(second.last, closeTo(-first.last, 1e-9));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('las bandas de dos rafagas distintas no son las mismas', (
      tester,
    ) async {
      await pumpSliced(tester, period: const Duration(seconds: 6));

      // Pasos de 15 ms, como los frames de una app real, y no un pump largo:
      // `_InterpolationSimulation.isDone` es estrictamente mayor, asi que el
      // `completed` de la rafaga llega en el frame siguiente al final de su
      // duracion. Sin ese frame no se programa la pausa.
      final bursts = <List<Rect>>[];
      var bursting = false;

      for (var step = 0; step < 1600; step++) {
        await tester.pump(const Duration(milliseconds: 15));
        final bands = bandsOf(tester);
        if (bands.isNotEmpty && !bursting) bursts.add(bands);
        bursting = bands.isNotEmpty;
        if (bursts.length == 2) break;
      }

      await tester.pumpWidget(const SizedBox());

      expect(bursts, hasLength(2));
      // Las bandas se recalculan en cada rafaga: cada glitch es distinto, que
      // es lo que se ve en el .mp4.
      expect(bursts[1], isNot(equals(bursts.first)));
    });

    testWidgets('con streaks pinta las lineas laterales y sin streaks no', (
      tester,
    ) async {
      await pumpSliced(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).streaks, isTrue);

      await tester.pumpWidget(const SizedBox());

      await pumpSliced(tester, streaks: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).streaks, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('la rafaga termina y las bandas se van', (tester) async {
      await pumpSliced(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).slices, isNotEmpty);

      await tester.pump(const Duration(milliseconds: 80));

      // El controller queda parado en 1 al terminar, y sin la guarda del build
      // las bandas se quedarian corridas para siempre.
      expect(slicedOf(tester).slices, isEmpty);
      expect(find.byType(_Marker), findsOneWidget);
    });

    testWidgets(
      'con reduce-motion no arranca ni el controller ni el Timer, y el hijo '
      'queda sin cortes',
      (tester) async {
        await pumpSliced(
          tester,
          disableAnimations: true,
          period: const Duration(seconds: 6),
        );

        await tester.pump(const Duration(seconds: 20));

        expect(slicedOf(tester).slices, isEmpty);
        expect(tester.binding.transientCallbackCount, 0);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('prender reduce-motion en vivo corta la rafaga', (
      tester,
    ) async {
      await pumpSliced(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).slices, isNotEmpty);

      await pumpSliced(tester, disableAnimations: true);

      expect(slicedOf(tester).slices, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('apagar reduce-motion en vivo vuelve a programar la rafaga', (
      tester,
    ) async {
      await pumpSliced(tester, disableAnimations: true);

      expect(slicedOf(tester).slices, isEmpty);

      await pumpSliced(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).slices, isNotEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('las bandas no le ganan el hit test al hijo real', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Center(
            child: SlicedBox(
              // period null: disparo unico, para que la rafaga este activa
              // cuando llega el tap. Sin esto toma el default de 6 segundos.
              period: null,
              child: GestureDetector(
                // opaque y no el default deferToChild: un SizedBox pelado no
                // es hit-testable y el tap no llegaria a ningun lado.
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: 90, height: 128),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Un solo GestureDetector: las bandas se pintan, no se insertan, asi que
      // no hay a quien ganarle el hit test. Antes eran tres, con dos bajo
      // IgnorePointer.
      expect(find.byType(GestureDetector), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byType(SlicedBox)));
      await tester.pump();

      expect(taps, 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con el TickerMode apagado no arranca ningun Timer', (
      tester,
    ) async {
      Future<void> pump({required bool ticking}) => tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: TickerMode(
            enabled: ticking,
            child: const Center(
              child: SlicedBox(period: null, child: _Marker()),
            ),
          ),
        ),
      );

      await pump(ticking: false);
      await tester.pump(const Duration(seconds: 10));

      expect(slicedOf(tester).slices, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);

      await pump(ticking: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(slicedOf(tester).slices, isNotEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar los parametros en vivo llega al render object', (
      tester,
    ) async {
      Future<void> pump({
        required double sliceOffset,
        required bool streaks,
        required Color streakColor,
        required double streakOverflow,
        required double streakStrokeWidth,
      }) => tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Center(
            child: SlicedBox(
              period: null,
              sliceOffset: sliceOffset,
              streaks: streaks,
              streakColor: streakColor,
              streakOverflow: streakOverflow,
              streakStrokeWidth: streakStrokeWidth,
              child: const _Marker(),
            ),
          ),
        ),
      );

      await pump(
        sliceOffset: 8,
        streaks: true,
        streakColor: const Color(0xFFFFFFFF),
        streakOverflow: 24,
        streakStrokeWidth: 1,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      await pump(
        sliceOffset: 16,
        streaks: false,
        streakColor: const Color(0xFF00FFFF),
        streakOverflow: 40,
        streakStrokeWidth: 3,
      );

      final render = slicedOf(tester);

      expect(render.sliceOffset, 16);
      expect(render.streaks, isFalse);
      expect(render.streakColor, const Color(0xFF00FFFF));
      expect(render.streakOverflow, 40);
      expect(render.streakStrokeWidth, 3);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('los streaks desbordan la caja, sin clip que los corte', (
      tester,
    ) async {
      await pumpSliced(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Antes esto se aseveraba sobre el `clipBehavior` del Stack. Ya no hay
      // Stack: el render object pinta al canvas sin clip propio, y lo unico que
      // recorta es el `clipRect` de cada banda. La propiedad que importa —que
      // las lineas salgan de la caja— se lee del painter.
      final render = slicedOf(tester);
      expect(render.streakOverflow, greaterThan(0));

      final canvas = _RecordingCanvas();
      SlicedStreaksPainter(
        bands: [
          for (final slice in render.slices)
            (top: slice.top, height: slice.height),
        ],
        color: render.streakColor,
        overflow: render.streakOverflow,
        strokeWidth: render.streakStrokeWidth,
      ).paint(canvas, size);

      expect(canvas.lines, isNotEmpty);
      for (final line in canvas.lines) {
        expect(line.$1.dx, lessThan(0));
        expect(line.$2.dx, greaterThan(size.width));
      }

      await tester.pumpWidget(const SizedBox());
    });
  });
}
