import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  /// Monta el cursor con el reloj corriendo o parado.
  Future<void> pumpCursor(
    WidgetTester tester, {
    bool disableAnimations = false,
    String glyph = '_',
    Duration period = const Duration(milliseconds: 200),
    TextStyle? style,
    double gap = 2,
  }) {
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: TerminalCursor(
              glyph: glyph,
              period: period,
              style: style,
              gap: gap,
              child: const Text('MAP'),
            ),
          ),
        ),
      ),
    );
  }

  /// La opacidad con la que se esta pintando el glifo.
  double glyphOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.byType(Opacity)).opacity;

  group('TerminalCursor', () {
    testWidgets('arranca con el glifo visible', (tester) async {
      await pumpCursor(tester);

      expect(find.text('_'), findsOneWidget);
      expect(glyphOpacity(tester), 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('alterna a medio periodo: 200 ms es el ciclo completo', (
      tester,
    ) async {
      await pumpCursor(tester);

      expect(glyphOpacity(tester), 1);

      await tester.pump(const Duration(milliseconds: 100));
      expect(glyphOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(glyphOpacity(tester), 1);

      // El widget se desmonta para que el Timer periodico no quede pendiente
      // en el teardown.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el ancho no cambia entre glifo prendido y apagado', (
      tester,
    ) async {
      await pumpCursor(tester);

      final visible = tester.getSize(find.byType(TerminalCursor));

      await tester.pump(const Duration(milliseconds: 100));

      // Lo que alterna es un Opacity, y un Opacity(0) no pinta pero mide
      // igual. Si en vez de eso se saliera el Text, el label saltaria cada
      // 100 ms.
      expect(glyphOpacity(tester), 0);
      expect(tester.getSize(find.byType(TerminalCursor)), visible);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el glifo no entra en el arbol de semantica', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpCursor(tester);

      // El guion bajo es decoracion: un lector de pantalla que lo anuncie
      // lee «MAP guion bajo» en vez de «MAP».
      expect(find.bySemanticsLabel('MAP'), findsOneWidget);
      expect(find.bySemanticsLabel('_'), findsNothing);

      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un texto largo wrappea en vez de desbordar la fila', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 72,
                child: TerminalCursor(
                  child: Text('Agregarlo a la biblioteca completa'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TerminalCursor)).width,
        lessThanOrEqualTo(72),
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con ancho no acotado el Flexible no revienta', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TerminalCursor(child: Text('MAP')),
            ),
          ),
        ),
      );
      await tester.pump();

      // Un `Flexible` bajo restricciones no acotadas revienta si la fila es
      // `MainAxisSize.max` o el fit es `tight`. Esta es `min` y el fit es
      // `loose`, asi que el hijo se layoutea igual que si no hubiera flex.
      expect(tester.takeException(), isNull);
      expect(find.text('MAP'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el glifo y el gap son parametrizables', (tester) async {
      await pumpCursor(tester, glyph: '▮', gap: 12);

      expect(find.text('▮'), findsOneWidget);
      expect(tester.widget<SizedBox>(find.byType(SizedBox)).width, 12);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con style nulo hereda el del entorno', (tester) async {
      await pumpCursor(tester);

      // Un TextStyle propio aca seria un AppFonts encubierto: la carpeta no
      // puede imponer tipografia.
      expect(tester.widget<Text>(find.text('_')).style, isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con style propio lo usa', (tester) async {
      const style = TextStyle(fontSize: 30);

      await pumpCursor(tester, style: style);

      expect(tester.widget<Text>(find.text('_')).style, style);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar el periodo en vivo reemplaza el Timer', (
      tester,
    ) async {
      await pumpCursor(tester);
      await pumpCursor(tester, period: const Duration(milliseconds: 600));

      // Con el periodo viejo ya habria alternado; con el nuevo, todavia no.
      await tester.pump(const Duration(milliseconds: 200));
      expect(glyphOpacity(tester), 1);

      await tester.pump(const Duration(milliseconds: 100));
      expect(glyphOpacity(tester), 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un periodo de cero no arranca ningun Timer', (tester) async {
      // Timer.periodic con Duration.zero dispararia sin parar.
      await pumpCursor(tester, period: Duration.zero);

      await tester.pump(const Duration(seconds: 1));

      expect(glyphOpacity(tester), 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
      'con reduce-motion no arranca ningun Timer y el glifo queda visible',
      (tester) async {
        await pumpCursor(tester, disableAnimations: true);

        await tester.pump(const Duration(seconds: 1));

        expect(glyphOpacity(tester), 1);
        expect(tester.binding.transientCallbackCount, 0);

        // Si hubiera quedado un Timer, el assert de teardown del framework
        // hace fallar el test aca.
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('pasar a Duration.zero en vivo cancela el Timer', (
      tester,
    ) async {
      await pumpCursor(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(glyphOpacity(tester), 0);

      // Sin el gate en didUpdateWidget esto dejaba un
      // `Timer.periodic(Duration.zero)` girando en cada turno del event loop:
      // el test no terminaba nunca.
      await pumpCursor(tester, period: Duration.zero);

      expect(glyphOpacity(tester), 1);

      await tester.pump(const Duration(seconds: 1));
      expect(glyphOpacity(tester), 1);
    });

    testWidgets('salir de Duration.zero en vivo arranca el parpadeo', (
      tester,
    ) async {
      await pumpCursor(tester, period: Duration.zero);

      await tester.pump(const Duration(seconds: 1));
      expect(glyphOpacity(tester), 1);

      await pumpCursor(tester);

      // Sin el gate en didUpdateWidget el cursor quedaba fijo para siempre:
      // `_blinking` seguia en false y nadie lo volvia a mirar.
      await tester.pump(const Duration(milliseconds: 100));
      expect(glyphOpacity(tester), 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'un periodo cuya mitad redondea a cero tampoco arranca el Timer',
      (tester) async {
        // El gate mira el periodo ya dividido, que es lo que recibe el Timer:
        // un microsegundo es mayor que cero pero su mitad no, y
        // `Timer.periodic(Duration.zero)` gira sin parar.
        await pumpCursor(tester, period: const Duration(microseconds: 1));

        await tester.pump(const Duration(seconds: 1));

        expect(glyphOpacity(tester), 1);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('con el TickerMode apagado no arranca ningun Timer', (
      tester,
    ) async {
      Future<void> pump({required bool ticking}) => tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TickerMode(
              enabled: ticking,
              child: const Center(child: TerminalCursor(child: Text('MAP'))),
            ),
          ),
        ),
      );

      // Este widget no usa ticker, asi que el TickerMode no lo frena solo: sin
      // el gate seguia llamando setState en una pantalla que ya no se ve.
      await pump(ticking: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(glyphOpacity(tester), 1);
      expect(tester.binding.transientCallbackCount, 0);

      await pump(ticking: true);
      await tester.pump(const Duration(milliseconds: 100));

      expect(glyphOpacity(tester), 0);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('prender reduce-motion en vivo para el parpadeo', (
      tester,
    ) async {
      await pumpCursor(tester);

      await tester.pump(const Duration(milliseconds: 100));
      expect(glyphOpacity(tester), 0);

      await pumpCursor(tester, disableAnimations: true);

      expect(glyphOpacity(tester), 1);

      await tester.pump(const Duration(seconds: 1));
      expect(glyphOpacity(tester), 1);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
