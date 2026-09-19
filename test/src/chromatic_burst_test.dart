import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Hijo de prueba, para contar sus copias en el arbol sin ambiguedad.
class _Marker extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 40);
}

void main() {
  Future<void> pumpBurst(
    WidgetTester tester, {
    bool disableAnimations = false,
    Duration? period = const Duration(seconds: 4),
    Duration burstDuration = const Duration(milliseconds: 120),
    BlendMode blendMode = BlendMode.plus,
    double jitter = 0.5,
    int seed = 42,
  }) {
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(
          child: ChromaticBurst(
            period: period,
            burstDuration: burstDuration,
            blendMode: blendMode,
            jitter: jitter,
            seed: seed,
            child: const _Marker(),
          ),
        ),
      ),
    );
  }

  /// El render object que pinta los fantasmas.
  ///
  /// La pintura ya no deja rastro en el arbol, asi que el observable es el
  /// render object: `find.byType(ChromaticBurst)` devuelve el elemento del
  /// widget y `findRenderObject` baja hasta el primer RenderObject, que es este.
  RenderChromaticBurst burstOf(WidgetTester tester) =>
      tester.renderObject<RenderChromaticBurst>(find.byType(ChromaticBurst));

  /// El color del pixel de `x` de la caja capturada, a la altura media.
  ///
  /// La caja mide 40x20 y el hijo 20x20 centrado, asi que el hijo ocupa `x` de
  /// 10 a 30. En el pico los fantasmas se corren 4 px: el izquierdo va de 6 a
  /// 26 y el derecho de 14 a 34. `x = 8` es el unico lugar donde esta el
  /// fantasma izquierdo sin el hijo encima, y `x = 32` el del derecho.
  Future<Color> ghostPixelAt(WidgetTester tester, int x) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('captura')),
    );

    late ByteData bytes;
    var width = 0;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      width = image.width;
      bytes = (await image.toByteData())!; // rawRgba es el default
    });

    final offset = ((10 * width) + x) * 4;

    return Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }

  Future<Color> ghostPixel(WidgetTester tester) => ghostPixelAt(tester, 8);

  /// Monta una rafaga sobre un fondo rojo y devuelve el color de un pixel que
  /// solo cubren el fondo y el fantasma izquierdo.
  ///
  /// La caja capturada mide 40x20 y el hijo 20x20 centrado, asi que el hijo
  /// ocupa `x` de 10 a 30 y el fantasma izquierdo —corrido 4 px en el pico— de 6
  /// a 26. El pixel de `x = 8` es el unico lugar donde el fantasma esta sin el
  /// hijo encima.
  Future<void> pumpGhost(
    WidgetTester tester, {
    required BlendMode blendMode,
    bool composited = false,
  }) {
    // Con `composited` el hijo fuerza su propia capa. Es el caso que dispara la
    // guarda de `needsCompositing`: 0,99 de opacidad es visualmente identico a
    // 1 pero deja el alpha en 252, y `RenderOpacity` compone con cualquier alpha
    // que no sea 0 ni 255.
    const box = ColoredBox(
      color: Color(0xFFFFFFFF),
      child: SizedBox(width: 20, height: 20),
    );

    return tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: RepaintBoundary(
            key: const ValueKey('captura'),
            child: SizedBox(
              width: 40,
              height: 20,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFFFF0000)),
                  ),
                  Center(
                    child: ChromaticBurst(
                      period: null,
                      blendMode: blendMode,
                      // Horizontal puro: la asercion mide un pixel concreto, y
                      // con el eje inclinado el fantasma se corre de renglon.
                      // La inclinacion tiene sus propios tests.
                      maxTilt: 0,
                      child: composited
                          ? const Opacity(opacity: 0.99, child: box)
                          : box,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ChromaticBurst', () {
    testWidgets(
      'el fantasma se compone contra el fondo con el blendMode, no con srcOver',
      (tester) async {
        // Es el unico expect que distingue `plus` de `srcOver`, y hace falta
        // porque el `saveLayer` es facil de dejar inerte sin que se note: un
        // hijo que fuerce su propia capa corta la grabacion del canvas, el
        // Paint del saveLayer termina aplicado a una capa vacia, y el arbol se
        // ve igual de sano. Medido: con el tinte en un `ColorFiltered` adentro
        // del blend, esto daba cian —identico a no tener blend—.
        //
        // Fondo rojo mas fantasma cian: con `plus` da blanco.
        await pumpGhost(tester, blendMode: BlendMode.plus);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        expect(await ghostPixel(tester), const Color(0xFFFFFFFF));

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('cambiar el blendMode en vivo llega al render object', (
      tester,
    ) async {
      await pumpGhost(tester, blendMode: BlendMode.plus);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(await ghostPixel(tester), const Color(0xFFFFFFFF));

      // Mismo arbol, otro blendMode: pasa por updateRenderObject y por el
      // setter. Sin ellos el render object se quedaria con `plus` en silencio,
      // y el arbol seguiria en pie igual — por eso el expect va sobre el pixel
      // y no sobre el arbol.
      await pumpGhost(tester, blendMode: BlendMode.srcOver);
      await tester.pump(const Duration(milliseconds: 1));

      expect(await ghostPixel(tester), const Color(0xFF00FFFF));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar offset y colores en vivo llega al render object', (
      tester,
    ) async {
      // Mismo molde que el test del blendMode: dos pumps sobre el mismo
      // arbol pasan por updateRenderObject, y los getters son el unico
      // observable de que el setter realmente escribio el campo.
      Future<void> pump({
        required double offset,
        required Color colorA,
        required Color colorB,
      }) {
        return tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Center(
              child: ChromaticBurst(
                period: null,
                offset: offset,
                colorA: colorA,
                colorB: colorB,
                child: const _Marker(),
              ),
            ),
          ),
        );
      }

      await pump(
        offset: 4,
        colorA: const Color(0xFF00FFFF),
        colorB: const Color(0xFFFF00FF),
      );

      await pump(
        offset: 10,
        colorA: const Color(0xFF000000),
        colorB: const Color(0xFFFFFFFF),
      );

      final render = burstOf(tester);
      expect(render.offset, 10);
      expect(render.colorA, const Color(0xFF000000));
      expect(render.colorB, const Color(0xFFFFFFFF));
      // El blendMode no cambia en este test: el default alcanza para leer el
      // getter, que ningun otro test toca.
      expect(render.blendMode, BlendMode.plus);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el hijo entra al arbol una sola vez, en reposo y en rafaga', (
      tester,
    ) async {
      await pumpBurst(tester, period: null);

      expect(find.byType(_Marker), findsOneWidget);
      expect(burstOf(tester).amount, 0);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Es la asercion titular del arreglo: la rafaga no reinserta el hijo, lo
      // repinta. De ahi que pueda llevar un GlobalKey, y de ahi que veinte
      // cajas simultaneas no sean sesenta subarboles.
      expect(burstOf(tester).amount, greaterThan(0));
      expect(find.byType(_Marker), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('los dos fantasmas se corren en sentidos opuestos', (
      tester,
    ) async {
      await pumpGhost(tester, blendMode: BlendMode.plus);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // El izquierdo lleva colorA y el derecho colorB. Con el hijo blanco de
      // 20x20 centrado, x = 8 solo lo cubre el izquierdo y x = 32 el derecho.
      expect(await ghostPixelAt(tester, 8), isNot(const Color(0xFFFF0000)));
      expect(await ghostPixelAt(tester, 32), isNot(const Color(0xFFFF0000)));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el pico esta en la mitad de la rafaga, no al final', (
      tester,
    ) async {
      await pumpBurst(tester, period: null);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 30));
      final quarter = burstOf(tester).amount;

      await tester.pump(const Duration(milliseconds: 30));
      final peak = burstOf(tester).amount;

      await tester.pump(const Duration(milliseconds: 30));
      final threeQuarters = burstOf(tester).amount;

      // sin(t*pi) y no una rampa: el maximo cae en la mitad.
      expect(peak, greaterThan(quarter));
      expect(threeQuarters, lessThan(peak));
      expect(peak, closeTo(1, 0.05));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con un hijo que compone capa no pinta los fantasmas', (
      tester,
    ) async {
      await pumpGhost(tester, blendMode: BlendMode.plus, composited: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Repintar un subarbol que retiene una capa la muda en vez de
      // duplicarla, asi que los fantasmas saldrian invisibles igual. La guarda
      // los saltea a proposito, y el pixel de al lado del hijo queda en el
      // fondo pelado.
      expect(await ghostPixelAt(tester, 8), const Color(0xFFFF0000));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('la rafaga termina y los fantasmas se van', (tester) async {
      await pumpBurst(tester, period: null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(burstOf(tester).amount, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 60));

      expect(burstOf(tester).amount, 0);
    });

    testWidgets('con period null dispara una sola vez y no vuelve', (
      tester,
    ) async {
      await pumpBurst(tester, period: null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(burstOf(tester).amount, 0);

      // Es el modo que va a usar NeuronReveal: un disparo, en el momento de la
      // resolucion, y despues el elemento queda limpio.
      await tester.pump(const Duration(seconds: 10));

      expect(burstOf(tester).amount, 0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('con period la rafaga vuelve despues de la pausa', (
      tester,
    ) async {
      // El periodo es el default de cuatro segundos.
      await pumpBurst(tester, jitter: 0);

      // Pasos de 60 ms, como los frames de una app real, y no un pump largo:
      // `_InterpolationSimulation.isDone` es estrictamente mayor, asi que el
      // `completed` de la rafaga llega en el frame **siguiente** al final de su
      // duracion. Sin ese frame no se programa la pausa, y un pump de cuatro
      // segundos se lo come.
      final starts = <int>[];
      var bursting = false;

      for (var step = 0; step < 200; step++) {
        await tester.pump(const Duration(milliseconds: 60));
        final now = burstOf(tester).amount > 0;
        if (now && !bursting) starts.add(step);
        bursting = now;
      }

      await tester.pumpWidget(const SizedBox());

      // Doce segundos de vida con periodo de cuatro: tres rafagas.
      expect(starts, hasLength(greaterThanOrEqualTo(2)));
      // Entre dos arranques hay el periodo mas la rafaga mas el frame de
      // cierre: 4200 ms, que en pasos de 60 ms son 70.
      expect(starts[1] - starts.first, inInclusiveRange(68, 72));
    });

    testWidgets('la fase inicial sale de la semilla y no de un cero fijo', (
      tester,
    ) async {
      /// En que paso de 50 ms arranca la primera rafaga, contando desde que se
      /// monta el widget. No se compara contra un valor concreto de
      /// `Random(seed).nextDouble()` —que nadie conoce de antemano— sino dos
      /// semillas entre si.
      Future<int> firstBurstStep(int seed) async {
        await pumpBurst(tester, seed: seed, jitter: 0);

        for (var step = 0; step < 100; step++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (burstOf(tester).amount > 0) {
            await tester.pumpWidget(const SizedBox());

            return step;
          }
        }

        await tester.pumpWidget(const SizedBox());

        return -1;
      }

      // 100 pasos de 50 ms son 5 segundos, mas que el periodo de 4: las dos
      // tienen que haber disparado.
      final one = await firstBurstStep(1);
      final seven = await firstBurstStep(7);

      expect(one, isNot(-1));
      expect(seven, isNot(-1));
      // Sin fase inicial las dos arrancarian en el mismo paso, y veinte cajas
      // de una lista destellarian al unisono.
      expect(one, isNot(seven));
    });

    testWidgets(
      'con reduce-motion no arranca ni el controller ni el Timer, y el hijo '
      'queda limpio',
      (tester) async {
        await pumpBurst(tester, disableAnimations: true);

        await tester.pump(const Duration(seconds: 10));

        expect(find.byType(_Marker), findsOneWidget);
        expect(burstOf(tester).amount, 0);
        expect(tester.binding.transientCallbackCount, 0);

        // Aberracion cromatica mas parpadeo rapido es el patron fotosensible:
        // si quedara un Timer, el assert de teardown del framework hace
        // fallar el test aca.
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('prender reduce-motion en vivo corta la rafaga', (
      tester,
    ) async {
      await pumpBurst(tester, period: null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(burstOf(tester).amount, greaterThan(0));

      await pumpBurst(tester, period: null, disableAnimations: true);

      expect(burstOf(tester).amount, 0);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('apagar reduce-motion en vivo vuelve a programar la rafaga', (
      tester,
    ) async {
      await pumpBurst(tester, disableAnimations: true, period: null);

      expect(burstOf(tester).amount, 0);

      await pumpBurst(tester, period: null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(burstOf(tester).amount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('los fantasmas no le ganan el hit test al hijo real', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Center(
            child: ChromaticBurst(
              period: null,
              child: GestureDetector(
                // opaque y no el default deferToChild: un SizedBox pelado no
                // es hit-testable y el tap no llegaria a ningun lado.
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Un solo GestureDetector: los fantasmas se pintan, no se insertan, asi
      // que no hay a quien ganarle el hit test. Antes eran tres, con dos bajo
      // IgnorePointer.
      expect(find.byType(GestureDetector), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byType(ChromaticBurst)));
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
              child: ChromaticBurst(period: null, child: _Marker()),
            ),
          ),
        ),
      );

      // En una ruta inactiva Flutter mutea los tickers, y un Timer no se
      // entera: veinte cajas de una lista que ya no se ve seguirian
      // despertandose a programar rafagas que no tickean.
      await pump(ticking: false);
      await tester.pump(const Duration(seconds: 10));

      expect(burstOf(tester).amount, 0);
      expect(tester.binding.transientCallbackCount, 0);

      // Y al volver a la ruta, arranca.
      await pump(ticking: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(burstOf(tester).amount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con jitter 0 todas las pausas miden lo mismo', (tester) async {
      await pumpBurst(tester, period: const Duration(seconds: 1), jitter: 0);

      final starts = <int>[];
      var bursting = false;

      for (var step = 0; step < 120; step++) {
        await tester.pump(const Duration(milliseconds: 50));
        final now = burstOf(tester).amount > 0;
        if (now && !bursting) starts.add(step);
        bursting = now;
      }

      await tester.pumpWidget(const SizedBox());

      expect(starts, hasLength(greaterThanOrEqualTo(3)));

      final gaps = [
        for (var i = 1; i < starts.length; i++) starts[i] - starts[i - 1],
      ];

      // Con jitter 0 no hay variacion: la tolerancia de un paso es por el
      // redondeo del muestreo de 50 ms, no por el jitter. Con jitter 0,5 las
      // pausas variarian hasta diez pasos.
      expect(
        gaps.every((gap) => (gap - gaps.first).abs() <= 1),
        isTrue,
        reason: 'pausas medidas en pasos de 50 ms: $gaps',
      );
    });

    testWidgets('el eje del desfase se inclina, y no siempre igual', (
      tester,
    ) async {
      await pumpBurst(tester, period: const Duration(milliseconds: 40));
      await tester.pump();

      // Un angulo por rafaga: se sortea en `_fire` y no en el build, asi que
      // dentro de una misma rafaga no se mueve.
      final inclinaciones = <double>{};
      var enRafaga = false;
      for (var paso = 0; paso < 400; paso++) {
        await tester.pump(const Duration(milliseconds: 15));
        final burst = burstOf(tester);
        if (burst.amount > 0 && !enRafaga) inclinaciones.add(burst.tilt);
        enRafaga = burst.amount > 0;
        if (inclinaciones.length == 3) break;
      }

      await tester.pumpWidget(const SizedBox());

      // Tres rafagas, tres angulos distintos: si fuera uno fijo, el efecto se
      // leeria como una inclinacion puesta a mano en vez de como ruido.
      expect(inclinaciones, hasLength(3));

      // Y ninguno se aparta mas del maximo de su eje, sea el de ida o el de
      // vuelta: el sorteo es `+-maxTilt`, mas media vuelta la mitad de las
      // veces.
      const maximo = 25 * math.pi / 180;
      for (final inclinacion in inclinaciones) {
        final desdeElEje = inclinacion.abs() > math.pi / 2
            ? (inclinacion.abs() - math.pi).abs()
            : inclinacion.abs();
        expect(desdeElEje, lessThanOrEqualTo(maximo + 1e-9));
      }
    });

    testWidgets('el lado de cada color tambien se sortea', (tester) async {
      await pumpBurst(tester, period: const Duration(milliseconds: 40));
      await tester.pump();

      // Media vuelta de diferencia es exactamente intercambiar los dos colores:
      // el fantasma que salia a la izquierda sale a la derecha.
      final dadosVuelta = <bool>{};
      var enRafaga = false;
      for (var paso = 0; paso < 600; paso++) {
        await tester.pump(const Duration(milliseconds: 15));
        final burst = burstOf(tester);
        if (burst.amount > 0 && !enRafaga) {
          dadosVuelta.add(burst.tilt.abs() > math.pi / 2);
        }
        enRafaga = burst.amount > 0;
        if (dadosVuelta.length == 2) break;
      }

      await tester.pumpWidget(const SizedBox());

      // Los dos lados aparecen: si siempre saliera el mismo, el pico se leeria
      // como un efecto con una direccion fija.
      expect(dadosVuelta, {true, false});
    });

    testWidgets('con maxTilt en 0 el desfase es horizontal puro', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Center(
            child: ChromaticBurst(period: null, maxTilt: 0, child: _Marker()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Es lo que hace `logo_animation.mp4`: cian a la izquierda y rojo a la
      // derecha, sin inclinacion y siempre del mismo lado. El default se aparta
      // de eso a proposito, en las dos cosas.
      expect(burstOf(tester).tilt, 0);

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
            child: ChromaticBurst(
              period: null,
              child: SizedBox(key: key, width: 40, height: 40),
            ),
          ),
        ),
      );

      // pump de warm-up: el primer tick del Ticker reporta elapsed 0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // El hijo entra al arbol una sola vez: los fantasmas se pintan desde el
      // render object en vez de reinsertarlo.
      expect(tester.takeException(), isNull);
      expect(key.currentContext, isNotNull);
      expect(find.byType(SizedBox), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
