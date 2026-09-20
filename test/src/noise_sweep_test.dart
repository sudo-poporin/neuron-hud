import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Canvas falso que registra los rectangulos dibujados, con que Paint, y los
/// recortes que se le aplicaron.
class _RecordingCanvas extends Fake implements Canvas {
  final List<Rect> rects = <Rect>[];
  final List<Paint> paints = <Paint>[];
  final List<Rect> clips = <Rect>[];
  int saves = 0;
  int restores = 0;

  @override
  void drawRect(Rect rect, Paint paint) {
    rects.add(rect);
    paints.add(paint);
  }

  @override
  void save() => saves++;

  @override
  void restore() => restores++;

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => clips.add(rect);
}

void main() {
  const size = Size(100, 50);

  _RecordingCanvas paintWith({
    required double t,
    NoiseSweepMode mode = NoiseSweepMode.progress,
    double bandWidth = 0.2,
    double trail = 0,
    AxisDirection direction = AxisDirection.right,
    int wispCount = 6,
    int seed = 42,
    Size canvasSize = size,
  }) {
    final canvas = _RecordingCanvas();

    NoiseSweepPainter(
      t: t,
      mode: mode,
      color: const Color(0xFFFFFFFF),
      bandWidth: bandWidth,
      trail: trail,
      direction: direction,
      wispCount: wispCount,
      seed: seed,
    ).paint(canvas, canvasSize);

    return canvas;
  }

  group('NoiseSweepPainter en modo progress', () {
    test('pinta una sola banda', () {
      expect(paintWith(t: 0.5).rects, hasLength(1));
    });

    test('el ancho de la banda es la fraccion pedida del ancho de la caja', () {
      // La fraccion es lo que hace que el mismo widget sirva sobre un icono de
      // 24 px y sobre una portada de 90x128.
      expect(paintWith(t: 0.5).rects.single.width, closeTo(20, 1e-9));
      expect(
        paintWith(t: 0.5, canvasSize: const Size(24, 24)).rects.single.width,
        closeTo(4.8, 1e-9),
      );
    });

    test('la banda avanza con t', () {
      final early = paintWith(t: 0.2).rects.single.left;
      final advanced = paintWith(t: 0.8).rects.single.left;

      expect(advanced, greaterThan(early));
    });

    test('en t 0 la banda esta afuera y en t 1 tambien, y afuera no pinta', () {
      // Entra desde fuera del borde y sale por el otro: por eso el estado
      // estatico de reduce-motion se parkea en 0,5 y no en 0.
      //
      // Y lo que queda afuera de la caja **no se dibuja**: `CustomPaint` no
      // clipea, asi que sin el recorte la banda y su estela se pintarian por
      // fuera del marco que dibujan las esquinas. En los dos extremos del
      // recorrido no queda nada adentro, asi que no se pinta nada.
      expect(paintWith(t: 0).rects, isEmpty);
      expect(paintWith(t: 1).rects, isEmpty);
    });

    test('la banda nunca se sale de la caja', () {
      final caja = Offset.zero & size;

      for (final t in <double>[0.05, 0.25, 0.5, 0.75, 0.95]) {
        for (final rect in paintWith(t: t).rects) {
          expect(caja.contains(rect.topLeft), isTrue, reason: 't = $t');
          expect(
            caja.contains(rect.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: 't = $t',
          );
        }
      }
    });

    test('con trail 0 no hay estela: una sola banda', () {
      expect(paintWith(t: 0.5).rects, hasLength(1));
    });

    test('la estela va detras de la banda y no delante', () {
      final rects = paintWith(t: 0.5, trail: 0.3).rects;

      expect(rects, hasLength(2));

      // Se pinta antes que la banda para que la banda quede encima: la estela
      // llega al color pleno justo en el borde que las une, y pintada despues
      // le comeria la cabeza.
      final estela = rects.first;
      final banda = rects.last;

      expect(estela.right, closeTo(banda.left, 1e-9));
    });

    test('con direction left la estela cambia de lado', () {
      final rects = paintWith(
        t: 0.5,
        trail: 0.3,
        direction: AxisDirection.left,
      ).rects;

      // Barriendo hacia la izquierda, «detras» es el lado derecho.
      expect(rects.first.left, closeTo(rects.last.right, 1e-9));
    });

    test('con direction down la estela tambien es horizontal', () {
      final rects = paintWith(
        t: 0.5,
        trail: 0.3,
        direction: AxisDirection.down,
      ).rects;

      // La estela cruza el ancho igual que la banda, y va arriba: barriendo
      // hacia abajo, «detras» es la parte de arriba.
      expect(rects.first.width, size.width);
      expect(rects.first.bottom, closeTo(rects.last.top, 1e-9));
    });

    test('la estela tampoco se sale de la caja', () {
      final caja = Offset.zero & size;

      // Es lo que la mantiene adentro del marco que dibujan las esquinas: a
      // 30 % del ancho, sin recorte, con la cabeza recien entrando la estela
      // se pintaria treinta pixeles a la izquierda del borde.
      for (final t in <double>[0.05, 0.2, 0.5, 0.8, 0.95]) {
        for (final rect in paintWith(t: t, trail: 0.3).rects) {
          expect(rect.left, greaterThanOrEqualTo(caja.left), reason: 't = $t');
          expect(rect.right, lessThanOrEqualTo(caja.right), reason: 't = $t');
        }
      }
    });

    test('con direction left la banda va al reves', () {
      final early = paintWith(
        t: 0.2,
        direction: AxisDirection.left,
      ).rects.single.left;
      final advanced = paintWith(
        t: 0.8,
        direction: AxisDirection.left,
      ).rects.single.left;

      expect(advanced, lessThan(early));
    });

    test('con direction down la banda es horizontal y baja', () {
      final rect = paintWith(
        t: 0.5,
        direction: AxisDirection.down,
      ).rects.single;

      expect(rect.width, size.width);
      expect(rect.height, closeTo(10, 1e-9));
    });

    test('con direction up la banda sube', () {
      final early = paintWith(
        t: 0.2,
        direction: AxisDirection.up,
      ).rects.single.top;
      final advanced = paintWith(
        t: 0.8,
        direction: AxisDirection.up,
      ).rects.single.top;

      expect(advanced, lessThan(early));
    });

    test('la banda lleva un shader, no un color plano', () {
      // Un rectangulo de color pleno se lee como una tapa; el gradiente
      // transparente-color-transparente es lo que lee como barrido.
      expect(paintWith(t: 0.5).paints.single.shader, isNotNull);
    });

    test('con bandWidth 0 no pinta nada', () {
      expect(paintWith(t: 0.5, bandWidth: 0).rects, isEmpty);
    });

    test('un bandWidth mayor a 1 se recorta a la caja completa', () {
      expect(
        paintWith(t: 0.5, bandWidth: 3).rects.single.width,
        closeTo(size.width, 1e-9),
      );
    });

    test('una caja de area cero no pinta nada', () {
      expect(paintWith(t: 0.5, canvasSize: Size.zero).rects, isEmpty);
    });
  });

  group('NoiseSweepPainter en modo ambient', () {
    _RecordingCanvas ambientWith({
      double t = 0.3,
      int wispCount = 6,
      int seed = 42,
      AxisDirection direction = AxisDirection.right,
    }) => paintWith(
      t: t,
      mode: NoiseSweepMode.ambient,
      wispCount: wispCount,
      seed: seed,
      direction: direction,
    );

    test('pinta un jiron por wispCount', () {
      expect(ambientWith().rects, hasLength(6));
      expect(ambientWith(wispCount: 2).rects, hasLength(2));
    });

    test('con wispCount 0 no pinta nada', () {
      expect(ambientWith(wispCount: 0).rects, isEmpty);
    });

    test('los jirones son difusos, no rectangulos duros', () {
      for (final paint in ambientWith().paints) {
        expect(paint.maskFilter, isNotNull);
      }
    });

    test('un jiron no salta de un borde al otro estando visible', () {
      // El wrap del ciclo ya estaba resuelto —vueltas enteras, asi que t=1 y
      // t=0 dan la misma posicion—, pero eso es la continuidad entre vueltas.
      // A mitad de vuelta el `% 1` tambien wrapea, y ahi el rectangulo estaba
      // medio adentro: saltaba de medio visible a la derecha a medio visible a
      // la izquierda, de un frame al otro.
      //
      // El salto de posicion sigue existiendo y tiene que existir: el jiron se
      // teletransporta. Lo que no puede pasar es que se teletransporte
      // **mientras se lo ve**.
      const pasos = 60;
      final caja = Offset.zero & size;
      Rect primero(double t) => ambientWith(t: t, wispCount: 1).rects.first;

      var previo = primero(0);
      for (var i = 1; i <= pasos; i++) {
        final actual = primero(i / pasos);
        final salto = (actual.left - previo.left).abs();

        if (salto > size.width / 2) {
          // No se exige intersección vacía: el muestreo es discreto, así que
          // las dos muestras caen un paso antes y un paso después del wrap
          // exacto y dejan una astilla de unos pocos píxeles. Lo que el
          // arreglo tiene que garantizar es que sea eso y no medio jirón:
          // sin él quedaban unos 16 px de un lado y 15 del otro, con él
          // quedan 2 y 0,1.
          final visiblePrevio = previo.intersect(caja).width;
          final visibleActual = actual.intersect(caja).width;
          final tolerancia = size.width / 20;

          expect(
            math.max(visiblePrevio, visibleActual),
            lessThan(tolerancia),
            reason: 'saltó de $previo a $actual con medio jirón a la vista',
          );
        }

        previo = actual;
      }
    });

    test('los jirones quedan recortados a la caja', () {
      // A diferencia de la banda y la estela, que se intersectan con la caja
      // antes de dibujarse, un jiron puede arrancar en negativo y terminar
      // pasado el borde. Y el blur lo estira todavia mas, asi que intersectar
      // el Rect no alcanza: hace falta recortar el canvas.
      final canvas = ambientWith();

      expect(canvas.clips, contains(Offset.zero & size));
      expect(canvas.saves, canvas.restores);
    });

    test('los jirones son de baja opacidad: es ambiente, no señal', () {
      for (final paint in ambientWith().paints) {
        expect(paint.color.a, lessThan(0.15));
      }
    });

    test('cada jiron tiene su fase, su tamaño y su opacidad', () {
      final rects = ambientWith().rects;
      final widths = rects.map((rect) => rect.width).toSet();
      final tops = rects.map((rect) => rect.top).toSet();

      // Sin eso los seis derivan en bloque y se lee como una sola banda.
      expect(widths, hasLength(greaterThan(1)));
      expect(tops, hasLength(greaterThan(1)));
    });

    test('los jirones no saltan cuando el ciclo wrapea de 1 a 0', () {
      // El controller repite, asi que t va de 1 a 0 en cada vuelta. Con una
      // velocidad fraccionaria `(phase + t * speed) % 1` no coincide entre los
      // dos extremos y el jiron teletransporta: medido, saltos de 6 a 30 px en
      // cada ciclo. Con vueltas enteras los extremos coinciden.
      //
      // La comparacion va con tolerancia y no por igualdad: `(phase + 1.0) % 1`
      // no da el mismo double que `phase`, y el residuo es de 1e-15 px. Lo que
      // el test afirma es que no hay salto **visible**.
      final start = ambientWith(t: 0).rects;
      final end = ambientWith(t: 1).rects;

      expect(end, hasLength(start.length));
      for (var i = 0; i < start.length; i++) {
        expect(end[i].left, closeTo(start[i].left, 0.001));
        expect(end[i].top, closeTo(start[i].top, 0.001));
      }
    });

    test('la misma semilla da el mismo campo', () {
      expect(ambientWith().rects, equals(ambientWith().rects));
    });

    test('semillas distintas dan campos distintos', () {
      expect(
        ambientWith(seed: 1).rects,
        isNot(equals(ambientWith(seed: 2).rects)),
      );
    });

    test('los jirones derivan con t', () {
      expect(
        ambientWith(t: 0.1).rects,
        isNot(equals(ambientWith(t: 0.6).rects)),
      );
    });

    test('con direction down los jirones son verticales', () {
      final rects = ambientWith(direction: AxisDirection.down).rects;

      for (final rect in rects) {
        expect(rect.height, greaterThan(rect.width));
      }
    });

    test('con direction up derivan al reves', () {
      expect(
        ambientWith(direction: AxisDirection.up).rects,
        isNot(equals(ambientWith(direction: AxisDirection.down).rects)),
      );
    });
  });

  group('NoiseSweepPainter.shouldRepaint', () {
    const base = NoiseSweepPainter(
      t: 0.5,
      mode: NoiseSweepMode.progress,
      color: Color(0xFFFFFFFF),
      bandWidth: 0.2,
      trail: 0,
      direction: AxisDirection.right,
      wispCount: 6,
      seed: 42,
    );

    test('repinta cuando avanza t', () {
      expect(
        const NoiseSweepPainter(
          t: 0.6,
          mode: NoiseSweepMode.progress,
          color: Color(0xFFFFFFFF),
          bandWidth: 0.2,
          trail: 0,
          direction: AxisDirection.right,
          wispCount: 6,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el modo', () {
      expect(
        const NoiseSweepPainter(
          t: 0.5,
          mode: NoiseSweepMode.ambient,
          color: Color(0xFFFFFFFF),
          bandWidth: 0.2,
          trail: 0,
          direction: AxisDirection.right,
          wispCount: 6,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el color', () {
      expect(
        const NoiseSweepPainter(
          t: 0.5,
          mode: NoiseSweepMode.progress,
          color: Color(0xFF000000),
          bandWidth: 0.2,
          trail: 0,
          direction: AxisDirection.right,
          wispCount: 6,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia el ancho de banda', () {
      expect(
        const NoiseSweepPainter(
          t: 0.5,
          mode: NoiseSweepMode.progress,
          color: Color(0xFFFFFFFF),
          bandWidth: 0.4,
          trail: 0,
          direction: AxisDirection.right,
          wispCount: 6,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la direccion', () {
      expect(
        const NoiseSweepPainter(
          t: 0.5,
          mode: NoiseSweepMode.progress,
          color: Color(0xFFFFFFFF),
          bandWidth: 0.2,
          trail: 0,
          direction: AxisDirection.left,
          wispCount: 6,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la cantidad de jirones', () {
      expect(
        const NoiseSweepPainter(
          t: 0.5,
          mode: NoiseSweepMode.progress,
          color: Color(0xFFFFFFFF),
          bandWidth: 0.2,
          trail: 0,
          direction: AxisDirection.right,
          wispCount: 3,
          seed: 42,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('repinta cuando cambia la semilla', () {
      expect(
        const NoiseSweepPainter(
          t: 0.5,
          mode: NoiseSweepMode.progress,
          color: Color(0xFFFFFFFF),
          bandWidth: 0.2,
          trail: 0,
          direction: AxisDirection.right,
          wispCount: 6,
          seed: 7,
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('no repinta con los mismos campos', () {
      expect(base.shouldRepaint(base), isFalse);
    });
  });

  group('NoiseSweep', () {
    Future<void> pumpSweep(
      WidgetTester tester, {
      bool disableAnimations = false,
      Duration period = const Duration(milliseconds: 1600),
      NoiseSweepMode mode = NoiseSweepMode.progress,
    }) {
      return tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Center(
            child: NoiseSweep(
              period: period,
              mode: mode,
              child: const SizedBox(width: 90, height: 128),
            ),
          ),
        ),
      );
    }

    NoiseSweepPainter painterOf(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(find.byType(CustomPaint).first)
                .foregroundPainter!
            as NoiseSweepPainter;

    testWidgets('pinta por delante del hijo', (tester) async {
      await pumpSweep(tester);

      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).first,
      );

      // Por delante y no por detras: `painter` dibujaria debajo del hijo, y una
      // portada opaca taparia el barrido entero.
      expect(customPaint.foregroundPainter, isA<NoiseSweepPainter>());
      expect(customPaint.painter, isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el barrido es continuo: repite sin parar', (tester) async {
      await pumpSweep(tester);

      // pump de warm-up: el primer tick del Ticker reporta elapsed 0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final quarter = painterOf(tester).t;

      await tester.pump(const Duration(milliseconds: 400));
      final half = painterOf(tester).t;

      expect(quarter, greaterThan(0));
      expect(half, greaterThan(quarter));

      // Un ciclo entero mas: sigue corriendo, no se quedo en 1.
      await tester.pump(const Duration(milliseconds: 1600));
      expect(painterOf(tester).t, closeTo(half, 0.01));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar el periodo en vivo cambia la velocidad', (
      tester,
    ) async {
      await pumpSweep(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await pumpSweep(tester, period: const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      // repeat() rearranca desde el valor actual, que era 0,25. Con el periodo
      // viejo 100 ms serian 0,0625 mas y daria 0,3125; con el nuevo son 0,25
      // mas y da 0,5. El expect tiene que distinguir los dos.
      expect(painterOf(tester).t, closeTo(0.5, 0.03));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un periodo de cero no arranca el reloj', (tester) async {
      // repeat() con duracion cero revienta con un assert.
      await pumpSweep(tester, period: Duration.zero);

      await tester.pump(const Duration(seconds: 1));

      expect(tester.binding.transientCallbackCount, 0);
      expect(painterOf(tester).t, 0.5);
    });

    testWidgets(
      'con reduce-motion el barrido queda quieto en el medio y sin ticker',
      (tester) async {
        await pumpSweep(tester, disableAnimations: true);

        await tester.pump(const Duration(seconds: 1));

        // 0,5 y no 0: en 0 la banda esta afuera de la caja y no se veria nada.
        expect(painterOf(tester).t, 0.5);
        expect(tester.binding.transientCallbackCount, 0);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('prender reduce-motion en vivo para el barrido', (
      tester,
    ) async {
      await pumpSweep(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await pumpSweep(tester, disableAnimations: true);

      expect(painterOf(tester).t, 0.5);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pasar a Duration.zero en vivo para el reloj sin reventar', (
      tester,
    ) async {
      await pumpSweep(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Sin el gate en didUpdateWidget esto revienta con
      // `_periodInSeconds > 0.0': is not true`, porque `repeat()` ya estaba
      // corriendo y `didChangeDependencies` no vuelve a correr por un cambio
      // de parametro.
      await pumpSweep(tester, period: Duration.zero);

      expect(painterOf(tester).t, 0.5);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('salir de Duration.zero en vivo arranca el reloj', (
      tester,
    ) async {
      await pumpSweep(tester, period: Duration.zero);

      expect(tester.binding.transientCallbackCount, 0);

      // El periodo es el default de 1600 ms.
      await pumpSweep(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Sin el gate en didUpdateWidget el barrido quedaba muerto para
      // siempre: `_sweeping` seguia en false y nadie lo volvia a mirar.
      expect(painterOf(tester).t, isNot(0.5));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con el TickerMode apagado no arranca el reloj', (
      tester,
    ) async {
      Future<void> pump({required bool ticking}) => tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: TickerMode(
            enabled: ticking,
            child: const Center(
              child: NoiseSweep(child: SizedBox(width: 90, height: 128)),
            ),
          ),
        ),
      );

      await pump(ticking: false);
      await tester.pump(const Duration(seconds: 1));

      expect(tester.binding.transientCallbackCount, 0);
      expect(painterOf(tester).t, 0.5);

      await pump(ticking: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 0,75 y no 0,25: `repeat()` rearranca desde el valor actual, que tras el
      // parkeo del TickerMode apagado es 0,5.
      expect(painterOf(tester).t, closeTo(0.75, 0.02));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el modo ambient tambien corre', (tester) async {
      await pumpSweep(tester, mode: NoiseSweepMode.ambient);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(painterOf(tester).mode, NoiseSweepMode.ambient);
      // closeTo y no greaterThan(0): 400 de 1600 ms son un cuarto de vuelta, y
      // un `greaterThan(0)` pasaria igual con el barrido parkeado en 0,5, o sea
      // con un controller que nunca arranco.
      expect(painterOf(tester).t, closeTo(0.25, 0.02));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
