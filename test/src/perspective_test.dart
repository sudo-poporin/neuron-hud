import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/src/perspective.dart';

/// Parte de prueba, para contarla en el arbol sin ambiguedad.
class _Part extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}

void main() {
  /// Los `Transform` que `Perspective` pone, de atras hacia adelante.
  List<Offset> translationsOf(WidgetTester tester) => tester
      .widgetList<Transform>(find.byType(Transform))
      .map(
        (transform) => Offset(
          transform.transform.getTranslation().x,
          transform.transform.getTranslation().y,
        ),
      )
      .toList();

  /// El render object que pinta la sombra de la primera parte.
  ///
  /// `_ShadowedPart` es privado, asi que no se lo puede buscar por tipo de
  /// widget. Se lo busca por tipo de render object, que si es publico.
  RenderShadowedPart shadowOf(WidgetTester tester) =>
      tester.allRenderObjects.whereType<RenderShadowedPart>().first;

  group('Perspective', () {
    testWidgets('el desfase es acumulado, no fijo', (tester) async {
      await tester.pumpWidget(
        const Perspective(shadow: false, children: [_Part(), _Part(), _Part()]),
      );

      // Tres partes, tres desfases: 0, un paso, dos pasos. Es lo que hace que
      // el apilado lea como profundidad y no como dos capas pegadas.
      expect(translationsOf(tester), const [
        Offset.zero,
        Offset(3, 2),
        Offset(6, 4),
      ]);
    });

    testWidgets('respeta un stepOffset propio', (tester) async {
      await tester.pumpWidget(
        const Perspective(
          stepOffset: Offset(10, 0),
          shadow: false,
          children: [_Part(), _Part()],
        ),
      );

      expect(translationsOf(tester), const [Offset.zero, Offset(10, 0)]);
    });

    testWidgets('cada parte entra al arbol una sola vez, con shadow y sin', (
      tester,
    ) async {
      await tester.pumpWidget(const Perspective(children: [_Part(), _Part()]));

      // Dos partes, no cuatro: la sombra se pinta desde el render object en vez
      // de reinsertar la parte. Cuando los efectos reinsertaban, eran cuatro,
      // con dos sombras que
      // tenian su propio State.
      expect(find.byType(_Part), findsNWidgets(2));
      expect(
        tester.allRenderObjects.whereType<RenderShadowedPart>(),
        hasLength(2),
      );

      await tester.pumpWidget(
        const Perspective(shadow: false, children: [_Part(), _Part()]),
      );

      expect(find.byType(_Part), findsNWidgets(2));

      // **Siguen montados, apagados.** Es el precio de que togglear la sombra
      // no remonte a las partes: sacarlos del arbol les cambiaria el ancestro
      // inmediato, y Flutter desmonta el subarbol cuando cambia el tipo en esa
      // posicion. Un render object que no pinta no cuesta nada; una parte con
      // estado que se remonta, si.
      final apagados = tester.allRenderObjects
          .whereType<RenderShadowedPart>()
          .toList();

      expect(apagados, hasLength(2));
      expect(apagados.every((render) => !render.enabled), isTrue);
    });

    testWidgets('una parte puede llevar un GlobalKey con shadow prendida', (
      tester,
    ) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        Center(
          child: Perspective(
            children: [SizedBox(key: key, width: 40, height: 20)],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(key.currentContext, isNotNull);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('con una parte que compone capa no pinta la sombra', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: Perspective(
            // 0,99 es visualmente identico a 1 pero deja el alpha en 252, y
            // RenderOpacity compone con cualquier alpha que no sea 0 ni 255.
            children: [Opacity(opacity: 0.99, child: _Part())],
          ),
        ),
      );

      // La guarda se dispara: repintar un subarbol que retiene una capa la muda
      // en vez de duplicarla. Que el salteo no pinte esta probado por pixeles
      // en `chromatic_burst_test.dart`, que es la misma rama de codigo.
      expect(shadowOf(tester).needsCompositing, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la sombra es una silueta negra difuminada, no un rectangulo', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Perspective(shadowOpacity: 0.5, children: [_Part()]),
      );

      // srcIn sobre negro deja la forma real de la parte, que es la razon de
      // no usar un BoxShadow: la sombra de un icono es la del icono. El tinte y
      // el blur viven ahora en el `Paint` del `saveLayer` del render object.
      expect(shadowOf(tester).opacity, 0.5);
    });

    testWidgets('la sombra oscurece el fondo detras de la parte', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: ValueKey('captura'),
            child: SizedBox(
              width: 60,
              height: 20,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  Positioned.fill(child: ColoredBox(color: Color(0xFFFF0000))),
                  Perspective(
                    stepOffset: Offset(10, 0),
                    shadowBlur: 0,
                    shadowOpacity: 1,
                    children: [
                      ColoredBox(
                        color: Color(0xFFFFFFFF),
                        child: SizedBox(width: 20, height: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

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

      // El blur y el tinte viajan ahora en un solo `Paint` de `saveLayer`, y el
      // orden de las dos operaciones lo fija Skia. Conmutan para un tinte srcIn
      // de color constante, pero eso se verifica y no se asume.
      //
      // La parte blanca ocupa x de 0 a 20 y su sombra, corrida 10 px sin blur,
      // de 10 a 30. En x = 25 hay sombra sola sobre el fondo rojo: con srcIn a
      // negro opaco el pixel tiene que quedar negro, no rojo.
      final offset = ((10 * width) + 25) * 4;

      expect(bytes.getUint8(offset), 0);
      expect(bytes.getUint8(offset + 1), 0);
      expect(bytes.getUint8(offset + 2), 0);
    });

    testWidgets('la sombra queda un paso detras de su parte', (tester) async {
      await tester.pumpWidget(
        const Perspective(stepOffset: Offset(5, 3), children: [_Part()]),
      );

      // Un solo Transform para una sola parte: el de la parte, que con i = 0 no
      // la mueve. El corrimiento de la sombra ya no es un widget, es un
      // `translate` en el canvas.
      expect(translationsOf(tester), const [Offset.zero]);
      expect(shadowOf(tester).shadowOffset, const Offset(5, 3));
    });

    testWidgets('el blur de la sombra sale de shadowBlur', (tester) async {
      await tester.pumpWidget(
        const Perspective(shadowBlur: 7, children: [_Part()]),
      );

      expect(shadowOf(tester).blur, 7);
    });

    testWidgets('cambiar los parametros en vivo llega al render object', (
      tester,
    ) async {
      // Sin parametros: los defaults de Perspective.
      await tester.pumpWidget(const Perspective(children: [_Part()]));

      expect(shadowOf(tester).shadowOffset, const Offset(3, 2));

      await tester.pumpWidget(
        const Perspective(
          stepOffset: Offset(9, 6),
          shadowOpacity: 0.8,
          shadowBlur: 5,
          children: [_Part()],
        ),
      );

      final render = shadowOf(tester);

      expect(render.shadowOffset, const Offset(9, 6));
      expect(render.opacity, 0.8);
      expect(render.blur, 5);
    });

    testWidgets('la sombra no le gana el hit test a su parte', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        Center(
          child: Perspective(
            children: [
              GestureDetector(
                // opaque y no el default deferToChild: un SizedBox pelado no
                // es hit-testable y el tap no llegaria a ningun lado.
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: 40, height: 20),
              ),
            ],
          ),
        ),
      );

      // Un solo GestureDetector: la sombra se pinta, no se inserta, asi que no
      // hay a quien ganarle el hit test. Antes eran dos, uno bajo
      // IgnorePointer.
      expect(find.byType(GestureDetector), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byType(Perspective)));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('una lista vacia no arma un Stack degenerado', (tester) async {
      await tester.pumpWidget(const Perspective(children: <Widget>[]));

      expect(find.byType(Stack), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('el Stack no clipea: el desfase se sale de la caja', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Perspective(shadow: false, children: [_Part(), _Part()]),
      );

      for (final stack in tester.widgetList<Stack>(find.byType(Stack))) {
        expect(stack.clipBehavior, Clip.none);
        // Alignment y no AlignmentDirectional: sin esto el Stack necesitaria un
        // Directionality ancestro para poder layoutear.
        expect(stack.alignment, Alignment.topLeft);
      }
    });
  });

  testWidgets('togglear la sombra no remonta a los hijos', (tester) async {
    // `shadow` alternaba entre envolver al hijo en `_ShadowedPart` y pasarlo
    // pelado, o sea que cambiaba el ancestro inmediato de cada hijo. Flutter
    // reconcilia por posicion y tipo: con el tipo cambiado desmonta y vuelve a
    // crear el subarbol, y un hijo con estado lo pierde.
    var montajes = 0;

    Widget conSombra({required bool shadow}) => MaterialApp(
      home: Perspective(
        shadow: shadow,
        children: [_ConEstado(onMount: () => montajes++)],
      ),
    );

    await tester.pumpWidget(conSombra(shadow: true));

    expect(montajes, 1);

    await tester.pumpWidget(conSombra(shadow: false));

    expect(montajes, 1);

    await tester.pumpWidget(conSombra(shadow: true));

    expect(montajes, 1);
  });
}

/// Hijo con estado que cuenta cuantas veces lo montaron.
class _ConEstado extends StatefulWidget {
  const new({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_ConEstado> createState() => _ConEstadoState();
}

class _ConEstadoState extends State<_ConEstado> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}
