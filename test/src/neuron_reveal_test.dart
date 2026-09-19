import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Monta [child] adentro de un `MediaQuery`, que es lo que el gate de
/// reduce-motion consulta.
Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 90, height: 128, child: child),
  ),
);

/// Avanza [frames] frames de 16 ms, como corre la app.
///
/// De a un frame y no de una: `_InterpolationSimulation.isDone` es estrictamente
/// mayor, asi que un `pump` largo se come el frame en que la fase cambia.
Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Cuantos frames de 16 ms hacen falta para pasar [duration].
int _framesFor(Duration duration) => (duration.inMilliseconds / 16).ceil();

/// Cuantos frames de 16 ms caben adentro de [duration] sin pasarse.
///
/// Las duraciones de las fases no son multiplos de 16, asi que el frame que
/// cruza una frontera cae siempre un poco despues: para afirmar algo *adentro*
/// de una fase hay que quedarse de este lado.
int _framesInside(Duration duration) => (duration.inMilliseconds / 16).floor();

double _progressOf<T extends Widget>(
  WidgetTester tester,
  double Function(T widget) read,
) => read(tester.widget<T>(find.byType(T)));

/// La opacidad con la que se pinta el contenido.
///
/// Sale del render object y no de un `Opacity`: el orquestador usa uno propio
/// que **no compone** con alpha 255, porque `RenderOpacity` fuerza capa con
/// cualquier alpha que no sea cero y eso les impide a los burst repintar al
/// hijo.
double _contentOpacity(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderContentOpacity>().first.opacity;

void main() {
  const child = Text('portada', textDirection: TextDirection.ltr);

  final guides = neuronPhaseDurations[NeuronPhase.guides]!;
  final dots = neuronPhaseDurations[NeuronPhase.dots]!;
  final noise = neuronPhaseDurations[NeuronPhase.noise]!;
  final condense = neuronPhaseDurations[NeuronPhase.condense]!;
  final chromatic = neuronPhaseDurations[NeuronPhase.chromatic]!;
  final slice = neuronPhaseDurations[NeuronPhase.slice]!;

  group('NeuronReveal, la secuencia', () {
    testWidgets('arranca con las tres capas apagadas y el contenido oculto', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();

      expect(_progressOf<GuideLines>(tester, (widget) => widget.progress!), 1);
      expect(_progressOf<DotMatrix>(tester, (widget) => widget.progress!), 1);
      expect(_progressOf<BlockNoise>(tester, (widget) => widget.progress!), 1);
      expect(_contentOpacity(tester), 0);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('las guias entran primero, y son andamio', (tester) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      await _pumpFrames(tester, _framesInside(guides));

      // A mitad de su fase las guias ya estan entrando...
      final aMitad = _progressOf<GuideLines>(tester, (w) => w.progress!);

      expect(aMitad, lessThan(1));
      expect(aMitad, greaterThan(0));
      // ...y los puntos todavia no empezaron.
      expect(_progressOf<DotMatrix>(tester, (widget) => widget.progress!), 1);

      await _pumpFrames(tester, _framesFor(guides) - _framesInside(guides));

      expect(_progressOf<GuideLines>(tester, (widget) => widget.progress!), 0);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('despues entran los puntos, y despues el ruido', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      await _pumpFrames(tester, _framesInside(guides + dots));

      // Los puntos casi enteros, el ruido sin empezar.
      expect(
        _progressOf<DotMatrix>(tester, (widget) => widget.progress!),
        lessThan(0.2),
      );
      expect(_progressOf<BlockNoise>(tester, (widget) => widget.progress!), 1);

      await _pumpFrames(
        tester,
        _framesInside(guides + dots + noise) - _framesInside(guides + dots),
      );

      // Y al final de la formacion, al reves: los puntos puestos y el ruido
      // casi entero. El ruido llega a 0 justo cuando arranca `condense`, que es
      // donde empieza a condensarse en la forma.
      expect(_progressOf<DotMatrix>(tester, (widget) => widget.progress!), 0);
      expect(
        _progressOf<BlockNoise>(tester, (widget) => widget.progress!),
        lessThan(0.1),
      );

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('en condense el contenido aparece y las dos capas se van', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise + condense));

      expect(_contentOpacity(tester), 1);
      expect(_progressOf<DotMatrix>(tester, (widget) => widget.progress!), 1);
      expect(_progressOf<BlockNoise>(tester, (widget) => widget.progress!), 1);
      // Las guias siguen: son lo ultimo que se va.
      expect(_progressOf<GuideLines>(tester, (widget) => widget.progress!), 0);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('el pico cromatico se monta en su fase y no antes', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise));

      expect(find.byType(ChromaticBurst), findsNothing);

      await _pumpFrames(tester, _framesFor(condense));

      // Montarlo es lo que dispara su tiro unico: con `period: null` cambiarle
      // el parametro despues no lo volveria a disparar.
      expect(find.byType(ChromaticBurst), findsOneWidget);
      expect(
        tester.widget<ChromaticBurst>(find.byType(ChromaticBurst)).period,
        isNull,
      );
      expect(
        tester
            .widget<ChromaticBurst>(find.byType(ChromaticBurst))
            .burstDuration,
        chromatic,
      );

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('el corte es posterior al pico, no simultaneo', (tester) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise + condense));

      expect(find.byType(SlicedBox), findsNothing);

      await _pumpFrames(tester, _framesFor(chromatic));

      expect(find.byType(SlicedBox), findsWidgets);
      expect(
        tester.widget<SlicedBox>(find.byType(SlicedBox).first).burstDuration,
        slice,
      );

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('al terminar queda el hijo pelado, sin capas ni efectos', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      // La secuencia entera, mas un frame por el `isDone` estricto.
      await _pumpFrames(
        tester,
        _framesFor(NeuronTimeline(phases: NeuronPhase.values).total) + 2,
      );

      expect(find.byType(GuideLines), findsNothing);
      expect(find.byType(DotMatrix), findsNothing);
      expect(find.byType(BlockNoise), findsNothing);
      expect(find.byType(ChromaticBurst), findsNothing);
      expect(find.byType(SlicedBox), findsNothing);
      expect(find.text('portada'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('sin slice, el revelado no corta nunca el contenido', (
      tester,
    ) async {
      // Es el contrato del rol texto: el slicing viene despues de
      // que el wordmark ya se leyo, asi que sobre un mensaje de carga lo
      // volveria ilegible justo cuando se lo esta leyendo.
      const sinSlice = [
        NeuronPhase.guides,
        NeuronPhase.dots,
        NeuronPhase.noise,
        NeuronPhase.condense,
        NeuronPhase.chromatic,
        NeuronPhase.settle,
      ];

      await tester.pumpWidget(
        _host(const NeuronReveal(phases: sinSlice, child: child)),
      );
      await tester.pump();

      final total = NeuronTimeline(phases: sinSlice).total;
      for (var i = 0; i < _framesFor(total) + 2; i++) {
        expect(find.byType(SlicedBox), findsNothing);
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('con la lista vacia pinta el hijo pelado y no arranca nada', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const NeuronReveal(phases: [], child: child)),
      );

      expect(find.byType(GuideLines), findsNothing);
      expect(find.text('portada'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('durations acorta la fase que se le pase', (tester) async {
      await tester.pumpWidget(
        _host(
          const NeuronReveal(
            phases: [NeuronPhase.guides, NeuronPhase.settle],
            durations: {NeuronPhase.guides: Duration(milliseconds: 32)},
            child: child,
          ),
        ),
      );
      await tester.pump();
      await _pumpFrames(tester, 2);

      expect(_progressOf<GuideLines>(tester, (widget) => widget.progress!), 0);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('un rebuild que no toca la secuencia no la reinicia', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      await _pumpFrames(tester, _framesInside(guides));

      final aMitad = _progressOf<GuideLines>(tester, (w) => w.progress!);

      // Cualquier rebuild del padre pasa por aca: si `didUpdateWidget` no
      // saliera temprano, el revelado volveria a arrancar de cero.
      await tester.pumpWidget(_host(const NeuronReveal(seed: 7, child: child)));
      await tester.pump();

      expect(tester.widget<GuideLines>(find.byType(GuideLines)).seed, 7);
      expect(
        _progressOf<GuideLines>(tester, (w) => w.progress!),
        lessThanOrEqualTo(aMitad),
      );

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('sin ink las tres capas dan los tres blancos del HUD', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();

      // El default tiene que reproducir exactamente las constantes de la
      // carpeta: es lo que hace que agregar el parametro no cambie nada para
      // quien no lo pasa.
      expect(
        tester.widget<BlockNoise>(find.byType(BlockNoise)).color,
        astralInk,
      );
      expect(
        tester.widget<GuideLines>(find.byType(GuideLines)).color.toARGB32(),
        astralInkDim.toARGB32(),
      );
      expect(
        tester.widget<DotMatrix>(find.byType(DotMatrix)).color.toARGB32(),
        astralInkFaint.toARGB32(),
      );

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('ink tiñe las tres capas, cada una con su alpha', (
      tester,
    ) async {
      const ink = Color(0xFF112233);

      await tester.pumpWidget(
        _host(const NeuronReveal(ink: ink, child: child)),
      );
      await tester.pump();

      // La alpha del color que se pasa se ignora: cada capa aplica la suya, que
      // es lo que las separa entre si.
      expect(
        tester.widget<BlockNoise>(find.byType(BlockNoise)).color.toARGB32(),
        ink.toARGB32(),
      );
      expect(
        tester.widget<GuideLines>(find.byType(GuideLines)).color.toARGB32(),
        ink.withValues(alpha: 0.4).toARGB32(),
      );
      expect(
        tester.widget<DotMatrix>(find.byType(DotMatrix)).color.toARGB32(),
        ink.withValues(alpha: 0.2).toARGB32(),
      );

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('la semilla llega a las capas y a los efectos', (tester) async {
      await tester.pumpWidget(
        _host(const NeuronReveal(seed: 42, child: child)),
      );
      await tester.pump();

      expect(tester.widget<GuideLines>(find.byType(GuideLines)).seed, 42);
      expect(tester.widget<BlockNoise>(find.byType(BlockNoise)).seed, 42);

      // Y a los dos efectos de rafaga, cada uno en su fase. `first` porque el
      // corte se monta adentro de la rafaga cromatica y aparece triplicado.
      await _pumpFrames(tester, _framesFor(guides + dots + noise + condense));

      expect(
        tester.widget<ChromaticBurst>(find.byType(ChromaticBurst).first).seed,
        42,
      );

      await _pumpFrames(tester, _framesFor(chromatic));

      expect(tester.widget<SlicedBox>(find.byType(SlicedBox).first).seed, 42);

      await tester.pumpWidget(_host(const SizedBox()));
    });
  });

  group('NeuronReveal, la espera del contenido', () {
    testWidgets('con ready en false la formacion corre y se para ahi', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const NeuronReveal(ready: false, child: child)),
      );
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise) + 2);

      // El esqueleto formado: las tres capas puestas y el contenido oculto.
      expect(_progressOf<GuideLines>(tester, (widget) => widget.progress!), 0);
      expect(_progressOf<DotMatrix>(tester, (widget) => widget.progress!), 0);
      expect(_progressOf<BlockNoise>(tester, (widget) => widget.progress!), 0);
      expect(_contentOpacity(tester), 0);
      // Y el controller quieto: no hay nada mas que animar hasta que llegue.
      expect(tester.binding.transientCallbackCount, 0);

      // Y sigue ahi un rato largo despues.
      await _pumpFrames(tester, 60);

      expect(_contentOpacity(tester), 0);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('cuando el contenido llega, el revelado sigue desde ahi', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const NeuronReveal(
            ready: false,
            phases: [
              NeuronPhase.guides,
              NeuronPhase.dots,
              NeuronPhase.noise,
              NeuronPhase.chromatic,
              NeuronPhase.slice,
              NeuronPhase.settle,
            ],
            child: child,
          ),
        ),
      );
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise) + 4);

      // Sin `condense`, el punto de espera cae en el arranque de `chromatic`.
      // La rafaga dispara **al montarse** y una sola vez: si se monta mientras
      // el contenido todavia no llego, el pico se gasta contra un hijo oculto y
      // cuando el contenido aparece ya no queda aberracion que mostrar.
      expect(find.byType(ChromaticBurst), findsNothing);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('con ready en false el burst no se consume esperando', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const NeuronReveal(ready: false, child: child)),
      );
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise) + 2);

      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await tester.pump();
      await _pumpFrames(tester, _framesFor(condense));

      expect(_contentOpacity(tester), 1);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets(
      'si el contenido llega antes de que termine la formacion, no se para',
      (tester) async {
        await tester.pumpWidget(
          _host(const NeuronReveal(ready: false, child: child)),
        );
        await tester.pump();
        await _pumpFrames(tester, _framesFor(guides));

        await tester.pumpWidget(_host(const NeuronReveal(child: child)));
        await tester.pump();
        await _pumpFrames(tester, _framesFor(dots + noise + condense));

        expect(_contentOpacity(tester), 1);

        await tester.pumpWidget(_host(const SizedBox()));
      },
    );
  });

  group('NeuronReveal, las tres salidas cortas', () {
    testWidgets(
      'con alreadyRevealed pinta el hijo pelado en el primer frame y no '
      'arranca ningun controller',
      (tester) async {
        await tester.pumpWidget(
          _host(const NeuronReveal(alreadyRevealed: true, child: child)),
        );

        expect(find.byType(GuideLines), findsNothing);
        expect(find.text('portada'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('con alreadyRevealed no se avisa: no hubo revelado', (
      tester,
    ) async {
      var avisos = 0;

      await tester.pumpWidget(
        _host(
          NeuronReveal(
            alreadyRevealed: true,
            onRevealStart: () => avisos++,
            child: child,
          ),
        ),
      );

      expect(avisos, 0);
    });

    testWidgets(
      'si el contenido llega adentro de la ventana, no hay revelado',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const NeuronReveal(
              ready: false,
              fastPathAfter: Duration(milliseconds: 120),
              child: child,
            ),
          ),
        );
        await tester.pump();
        await _pumpFrames(tester, 3);

        await tester.pumpWidget(
          _host(
            const NeuronReveal(
              fastPathAfter: Duration(milliseconds: 120),
              child: child,
            ),
          ),
        );

        expect(find.byType(GuideLines), findsNothing);
        expect(find.text('portada'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('si el contenido tarda mas que la ventana, se revela', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const NeuronReveal(
            ready: false,
            fastPathAfter: Duration(milliseconds: 120),
            child: child,
          ),
        ),
      );
      await tester.pump();
      await _pumpFrames(tester, 20);

      await tester.pumpWidget(
        _host(
          const NeuronReveal(
            fastPathAfter: Duration(milliseconds: 120),
            child: child,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GuideLines), findsOneWidget);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('el fast path si avisa, y es lo que protege al Hero', (
      tester,
    ) async {
      var avisos = 0;

      await tester.pumpWidget(
        _host(
          NeuronReveal(
            fastPathAfter: const Duration(milliseconds: 120),
            onRevealStart: () => avisos++,
            child: child,
          ),
        ),
      );

      // Sin este aviso, la portada cacheada queda fuera del registro y la
      // primera vez que el Hero vuele sobre ella si corre la secuencia entera.
      expect(avisos, 1);
      expect(find.byType(GuideLines), findsNothing);
    });

    testWidgets('una salida corta no se deshace con un rebuild posterior', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const NeuronReveal(
            fastPathAfter: Duration(milliseconds: 120),
            child: child,
          ),
        ),
      );

      expect(find.byType(GuideLines), findsNothing);

      // La ventana del fast path se cierra a los 120 ms, asi que la condicion
      // que corto el revelado ya no vale.
      await tester.pump();
      await _pumpFrames(tester, 10);

      // Y un `ListView.builder` reconstruye sus filas todo el tiempo: un cambio
      // de `phases` o de `durations` entra por `didUpdateWidget` con `force`.
      // Sin el latch, la fila que ya se dio por revelada arranca a animar.
      await tester.pumpWidget(
        _host(
          const NeuronReveal(
            phases: [NeuronPhase.guides, NeuronPhase.settle],
            fastPathAfter: Duration(milliseconds: 120),
            child: child,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GuideLines), findsNothing);
      expect(find.text('portada'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('con reducir movimiento no se avisa', (tester) async {
      var avisos = 0;

      await tester.pumpWidget(
        _host(
          NeuronReveal(onRevealStart: () => avisos++, child: child),
          reduceMotion: true,
        ),
      );

      // No hubo revelado, y una reconstruccion posterior tampoco lo va a
      // correr: el gate la va a frenar igual.
      expect(avisos, 0);
    });
  });

  group('NeuronReveal, onRevealStart', () {
    testWidgets('se dispara en el frame en que arranca, no al terminar', (
      tester,
    ) async {
      var avisos = 0;

      await tester.pumpWidget(
        _host(NeuronReveal(onRevealStart: () => avisos++, child: child)),
      );

      expect(avisos, 1);

      await _pumpFrames(
        tester,
        _framesFor(NeuronTimeline(phases: NeuronPhase.values).total) + 2,
      );

      expect(avisos, 1);
    });

    testWidgets('con ready en false se avisa recien cuando el contenido esta', (
      tester,
    ) async {
      var avisos = 0;

      await tester.pumpWidget(
        _host(
          NeuronReveal(
            ready: false,
            onRevealStart: () => avisos++,
            child: child,
          ),
        ),
      );
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise) + 2);

      // La formacion corrio, pero el elemento no se mostro: marcarlo aca
      // dejaria al registro diciendo que ya se vio algo que no llego.
      expect(avisos, 0);

      await tester.pumpWidget(
        _host(NeuronReveal(onRevealStart: () => avisos++, child: child)),
      );
      await tester.pump();

      expect(avisos, 1);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets(
      'sin ninguna fase de resolucion, ready no tiene donde aplicar y se '
      'avisa igual',
      (tester) async {
        var avisos = 0;

        // Sin `condense`, `chromatic`, `slice` ni `settle` el punto de espera
        // cae al final: no hay nada que esperar, y la formacion es el revelado
        // entero. Si `ready` frenara igual, el elemento se mostraria —sin
        // `condense` el contenido esta visible desde el primer frame— y el
        // registro no se enteraria nunca.
        await tester.pumpWidget(
          _host(
            NeuronReveal(
              phases: const [
                NeuronPhase.guides,
                NeuronPhase.dots,
                NeuronPhase.noise,
              ],
              ready: false,
              onRevealStart: () => avisos++,
              child: child,
            ),
          ),
        );
        await tester.pump();

        expect(avisos, 1);

        await tester.pumpWidget(_host(const SizedBox()));
      },
    );

    testWidgets('no se avisa dos veces si el widget se reconstruye', (
      tester,
    ) async {
      var avisos = 0;

      Widget build(Duration guides) => _host(
        NeuronReveal(
          durations: {NeuronPhase.guides: guides},
          onRevealStart: () => avisos++,
          child: child,
        ),
      );

      await tester.pumpWidget(build(const Duration(milliseconds: 120)));
      await tester.pump();
      await tester.pumpWidget(build(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(avisos, 1);

      await tester.pumpWidget(_host(const SizedBox()));
    });
  });

  group('NeuronReveal adentro de un Stagger', () {
    testWidgets('el revelado espera el retraso antes de arrancar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Stagger(index: 2, child: NeuronReveal(child: child))),
      );
      await tester.pump();
      // 160 ms de los 180 que espera el tercer hermano: sin el retraso, las
      // guias ya habrian entrado enteras.
      await _pumpFrames(tester, 10);

      expect(_progressOf<GuideLines>(tester, (widget) => widget.progress!), 1);

      await _pumpFrames(tester, _framesFor(guides) + 2);

      expect(_progressOf<GuideLines>(tester, (widget) => widget.progress!), 0);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('el aviso tambien espera su turno', (tester) async {
      var avisos = 0;

      await tester.pumpWidget(
        _host(
          Stagger(
            index: 2,
            child: NeuronReveal(onRevealStart: () => avisos++, child: child),
          ),
        ),
      );
      await tester.pump();

      expect(avisos, 0);

      await _pumpFrames(tester, 13);

      expect(avisos, 1);

      await tester.pumpWidget(_host(const SizedBox()));
    });
  });

  group('NeuronReveal, el par de la aberracion', () {
    /// Avanza hasta que la fase `chromatic` esta corriendo.
    ///
    /// Es el idioma del resto del archivo: un `pump` de arranque y despues
    /// frames de 16 ms, porque `_InterpolationSimulation.isDone` es
    /// estrictamente mayor y un `pump` largo se come el frame del cambio.
    Future<void> hastaElPico(WidgetTester tester) async {
      await tester.pump();
      await _pumpFrames(tester, _framesFor(guides + dots + noise + condense));
    }

    testWidgets('sin colores el pico es el cian y rojo de la referencia', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const NeuronReveal(child: child)));
      await hastaElPico(tester);

      final burst = tester.widget<ChromaticBurst>(
        find.byType(ChromaticBurst).first,
      );

      expect(burst.colorA.toARGB32(), astralChromaticA.toARGB32());
      expect(burst.colorB.toARGB32(), astralChromaticB.toARGB32());
      expect(burst.offset, 4);

      await tester.pumpWidget(_host(const SizedBox()));
    });

    testWidgets('los colores y el desfase llegan al pico', (tester) async {
      const a = Color(0xFF112233);
      const b = Color(0xFF445566);

      await tester.pumpWidget(
        _host(
          const NeuronReveal(
            chromaticA: a,
            chromaticB: b,
            chromaticOffset: 20,
            child: child,
          ),
        ),
      );
      await hastaElPico(tester);

      final burst = tester.widget<ChromaticBurst>(
        find.byType(ChromaticBurst).first,
      );

      expect(burst.colorA.toARGB32(), a.toARGB32());
      expect(burst.colorB.toARGB32(), b.toARGB32());
      expect(burst.offset, 20);

      await tester.pumpWidget(_host(const SizedBox()));
    });
  });

  group('NeuronReveal, reducir movimiento', () {
    testWidgets('pinta el hijo pelado y no arranca ningun controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const NeuronReveal(child: child), reduceMotion: true),
      );

      expect(find.byType(GuideLines), findsNothing);
      expect(find.text('portada'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('en una ruta inactiva tampoco arranca', (tester) async {
      await tester.pumpWidget(
        _host(
          const TickerMode(enabled: false, child: NeuronReveal(child: child)),
        ),
      );

      expect(find.byType(GuideLines), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('NeuronReveal, el hijo no se duplica', () {
    testWidgets('el hijo puede llevar un GlobalKey y la secuencia no lo rompe', (
      tester,
    ) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        _host(NeuronReveal(child: SizedBox(key: key, width: 90, height: 128))),
      );

      // La secuencia entera en pasos de 15 ms, como los frames de una app real.
      // Nada de pumpAndSettle: los efectos animan indefinidamente.
      //
      // NeuronReveal remonta a su hijo tres veces por su cuenta —al entrar en
      // `chromatic`, al entrar en `slice` y al terminar—, pero un remontaje
      // secuencial es legal para un GlobalKey. Lo que lo rompia era que los dos
      // burst apilaran copias, y ya no lo hacen.
      for (var step = 0; step < 80; step++) {
        await tester.pump(const Duration(milliseconds: 15));
        expect(tester.takeException(), isNull);
      }

      expect(key.currentContext, isNotNull);
      expect(find.byType(SizedBox), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'el burst del revelado no compone capa, asi que la rafaga corre',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const NeuronReveal(
              child: ColoredBox(
                color: Color(0xFFFFFFFF),
                child: SizedBox(width: 90, height: 128),
              ),
            ),
          ),
        );

        // Avanzar hasta que el burst este montado, que pasa al entrar en la fase
        // `chromatic`.
        var burst = tester.allRenderObjects.whereType<RenderChromaticBurst>();
        for (var step = 0; step < 80 && burst.isEmpty; step++) {
          await tester.pump(const Duration(milliseconds: 15));
          burst = tester.allRenderObjects.whereType<RenderChromaticBurst>();
        }

        expect(burst, isNotEmpty);

        // Si esto se rompe, la rafaga se apaga sola en cada portada de la app y
        // nadie se entera. Depende de dos cosas ajenas: que el `Opacity` del
        // orquestador vaya en alpha 255 en esta fase, y que `octo_image` —abajo de
        // CachedNetworkImage— no deje un `FadeWidget` puesto una vez que la
        // imagen resolvio. Las dos son ciertas hoy y ninguna es nuestra.
        expect(burst.first.needsCompositing, isFalse);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
