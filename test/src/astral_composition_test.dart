import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  group('composicion de las cuatro capas', () {
    testWidgets(
      'anidadas, el orden de anidado es el inverso del orden de pintado y el '
      'de afuera queda arriba: es el 統合 del diagrama',
      (tester) async {
        await tester.pumpWidget(
          const SizedBox(
            width: 90,
            height: 128,
            child: GuideLines(
              child: TechFrame(child: BlockNoise(child: DotMatrix())),
            ),
          ),
        );

        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((paint) => paint.foregroundPainter.runtimeType)
            .toList();

        expect(painters, [
          GuideLinesPainter,
          TechFramePainter,
          BlockNoisePainter,
          DotMatrixPainter,
        ]);
      },
    );

    testWidgets('las tres capas con progress lo reciben', (tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 90,
          height: 128,
          child: GuideLines(
            progress: 0.5,
            child: TechFrame(
              child: BlockNoise(progress: 0.5, child: DotMatrix(progress: 0.5)),
            ),
          ),
        ),
      );

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.foregroundPainter)
          .toList();

      // El del medio es el de `TechFrame`, que hoy no toma `progress`: en la
      // referencia el marco queda despues de que el elemento resolvio.
      //
      // Este expect fija la posicion, no la ausencia del campo. Que
      // `TechFramePainter` no tenga `progress` lo garantiza su propia
      // declaracion, y ningun test puede afirmarlo: un `expect` sobre un
      // campo que no existe no compila.
      expect(painters[1], isA<TechFramePainter>());
      expect((painters[0]! as GuideLinesPainter).progress, 0.5);
      expect((painters[2]! as BlockNoisePainter).progress, 0.5);
      expect((painters[3]! as DotMatrixPainter).progress, 0.5);
    });
  });

  group('composicion de las capas con los efectos de ritmo', () {
    testWidgets(
      'un efecto con reloj envuelve las cuatro capas sin pelearse con ellas',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(),
            child: SizedBox(
              width: 90,
              height: 128,
              child: NoiseSweep(
                child: GuideLines(
                  child: TechFrame(child: BlockNoise(child: DotMatrix())),
                ),
              ),
            ),
          ),
        );

        // Es el anidado que documenta el sistema: el de afuera queda arriba.
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((paint) => paint.foregroundPainter.runtimeType)
            .toList();

        expect(painters, [
          NoiseSweepPainter,
          GuideLinesPainter,
          TechFramePainter,
          BlockNoisePainter,
          DotMatrixPainter,
        ]);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('anidar los dos burst ya no multiplica el interno', (
      tester,
    ) async {
      // La composicion que el contrato le asigna al rol imagen, con los dos
      // efectos de rafaga por encima.
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: SizedBox(
            width: 90,
            height: 128,
            child: ChromaticBurst(
              period: null,
              child: SlicedBox(
                period: null,
                child: GuideLines(
                  child: TechFrame(child: BlockNoise(child: DotMatrix())),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(ChromaticBurst), findsOneWidget);
      // Uno, no tres. Los dos efectos pintan su hijo desde un render object
      // en vez de reinsertarlo, asi que anidarlos no multiplica nada: hay un
      // solo SlicedBox, con un solo State y un solo ticker, aunque los dos
      // esten en rafaga a la vez.
      //
      // Este test aseveraba lo contrario hasta que los efectos dejaron de
      // reinsertar a su hijo, y el comentario decia
      // que la multiplicacion era «el costo de anidar dos efectos que
      // duplican». Ese costo ya no existe.
      //
      // Lo que sigue en pie es el orden de `logo_animation.mp4`: el slicing
      // viene **despues** del pico cromatico, no al mismo tiempo. Eso es
      // diseno, no una limitacion tecnica.
      expect(find.byType(SlicedBox), findsOneWidget);
      expect(find.byType(GuideLines), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Perspective apila capas enteras como partes', (tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 90,
          height: 128,
          child: Perspective(
            children: [
              DotMatrix(child: SizedBox(width: 90, height: 128)),
              TechFrame(child: SizedBox(width: 90, height: 128)),
            ],
          ),
        ),
      );

      // Una de cada una, no dos. Cada parte entra al arbol una sola vez: su
      // sombra se pinta desde el render object en vez de reinsertarla. Antes de
      // que los efectos dejaran de reinsertar, este test contaba dos: una por
      // parte y una por sombra.
      expect(find.byType(DotMatrix), findsOneWidget);
      expect(find.byType(TechFrame), findsOneWidget);
    });
  });

  group('composicion de las entradas con el resto', () {
    testWidgets('ExpandLine abre una pila de capas sin pelearse con ella', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: ExpandLine(
              child: SizedBox(
                width: 90,
                height: 128,
                child: GuideLines(
                  child: TechFrame(child: BlockNoise(child: DotMatrix())),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Durante el hold la caja mide la linea y las cuatro capas siguen
      // adentro, recortadas.
      expect(tester.getSize(find.byType(ExpandLine)).height, 1);
      expect(find.byType(GuideLines), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.getSize(find.byType(ExpandLine)).height, 128);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'un Stagger arriba de la lista le corre el arranque a cada fila, y el '
      'primero no espera',
      (tester) async {
        Widget fila(int index) => SizedBox(
          width: 90,
          height: 128,
          child: Stagger(
            index: index,
            count: 3,
            child: const NeuronReveal(
              child: Text('portada', textDirection: TextDirection.ltr),
            ),
          ),
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [fila(0), fila(1)],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        final progresos = tester
            .widgetList<GuideLines>(find.byType(GuideLines))
            .map((widget) => widget.progress)
            .toList();

        // El primero ya arranco y el segundo todavia no: eso es el escalonado.
        expect(progresos, hasLength(2));
        expect(progresos.first, lessThan(1));
        expect(progresos.last, 1);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'NeuronReveal nunca tiene los dos burst en rafaga a la vez: por eso la '
      'referencia los pone en fases',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 90,
                height: 128,
                child: NeuronReveal(
                  child: Text('portada', textDirection: TextDirection.ltr),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final total = NeuronTimeline(phases: NeuronPhase.values).total;
        var conCorte = 0;
        var multiplicado = 0;
        for (var i = 0; i < (total.inMilliseconds / 16).ceil() + 2; i++) {
          final copias = find.byType(SlicedBox).evaluate().length;
          if (copias > 0) conCorte++;
          if (copias > 1) multiplicado++;
          await tester.pump(const Duration(milliseconds: 16));
        }

        // La primera asercion es la que evita que el test pase por no haber
        // corte ninguno.
        expect(conCorte, greaterThan(1));
        // Y esta es la que importa. Mientras los efectos reinsertaban a su
        // hijo, admitia hasta dos frames con
        // copias, porque el solapamiento del borde entre fases dejaba a
        // ChromaticBurst apilando SlicedBox. Ahora los efectos pintan sin
        // reinsertar, asi que no hay ni un frame con mas de uno.
        expect(multiplicado, 0);
      },
    );
  });
}
