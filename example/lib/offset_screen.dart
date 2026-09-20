import 'package:example/demo_section.dart';
import 'package:flutter/material.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// El **modificador**: las partes de un elemento, desfasadas.
///
/// **No rota nada.** El estudio del que sale pone la versión frontal y la que
/// tiene perspectiva lado a lado, y lo que cambia entre las dos es que las
/// partes están corridas unas respecto de otras: la placa al fondo, el ícono
/// desplazado, el badge empujado. Un `Matrix4` sobre el hijo entero inclina
/// todo junto, que es exactamente lo que el estudio descarta.
///
/// **Es la única de las cinco familias sin reloj propio y sin `progress`.** No
/// corre ni en bucle ni una vez: modifica cómo se apila un elemento y se queda
/// así. Por eso esta pantalla se ve igual en una captura fija que en vivo, y es
/// la única del example de la que eso es cierto.
class OffsetScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        DemoSection(
          title: 'PERSPECTIVE — EL DEFAULT',
          caption:
              'Tres partes, de atrás hacia adelante: la primera queda en su '
              'lugar y cada siguiente se corre un paso más. La sombra de cada '
              'una es lo que separa los planos.',
          child: _Badge(),
        ),
        DemoSection(
          title: 'UN PASO MÁS LARGO, SIN SOMBRA',
          caption:
              'El mismo elemento con `stepOffset` de 10 por 7 y `shadow` en '
              '`false`. Sin la sombra el desfase se lee como un error de '
              'registro y no como profundidad: las dos cosas van juntas.',
          child: _Badge(stepOffset: Offset(10, 7), shadow: false),
        ),
        DemoSection(
          title: 'UNA SOLA PARTE',
          caption:
              'Con un solo hijo no hay desfase que acumular: la parte 0 se '
              'corre `stepOffset * 0`, o sea nada. **La sombra sí se pinta**, '
              'porque cada parte la lleva por su cuenta y no depende de cuántas '
              'haya. Está acá porque es el caso que confunde: no es que el '
              'modificador no haga nada, es que lo único que hace con una sola '
              'parte es la sombra.',
          child: _Badge(parts: 1),
        ),
      ],
    );
  }
}

/// Un elemento de HUD en tres partes: la placa, el ícono y el badge.
///
/// Son formas y no texto a propósito: desfasar las partes de una palabra la
/// vuelve ilegible, y el logo de la referencia es frontal.
class _Badge extends StatelessWidget {
  const new({
    this.parts = 3,
    this.stepOffset = const Offset(3, 2),
    this.shadow = true,
  });

  /// Cuántas de las tres partes se apilan.
  final int parts;

  /// Desfase que se acumula por parte.
  final Offset stepOffset;

  /// Si cada parte lleva su sombra.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 120,
      child: Perspective(
        stepOffset: stepOffset,
        shadow: shadow,
        children: [
          Container(
            width: 120,
            height: 84,
            decoration: BoxDecoration(
              color: astralInkFaint,
              border: Border.all(color: astralInkDim),
            ),
          ),
          if (parts > 1)
            const Padding(
              padding: EdgeInsets.only(left: 18, top: 14),
              child: Icon(Icons.radar, size: 56, color: astralInk),
            ),
          if (parts > 2)
            Padding(
              padding: const EdgeInsets.only(left: 62, top: 54),
              child: Container(
                width: 46,
                height: 20,
                alignment: Alignment.center,
                color: astralChromaticA,
                child: const Text(
                  'LV 07',
                  style: TextStyle(
                    color: Color(0xFF101014),
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
