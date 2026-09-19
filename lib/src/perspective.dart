import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'perspective_render.dart';

/// Apila las partes de un elemento con un desfase acumulado y una sombra.
///
/// Es la lectura del estudio 【角度・ズレ調整】 —«ajuste de angulo y desfase»— de
/// los videos `036_UIblog_onishi_01.mp4` y `_02.mp4` del blog oficial de
/// PlatinumGames en https://www.platinumgames.com/official-blog/article/10422.
///
/// **No rota nada.** El estudio pone la version frontal y la version con
/// perspectiva lado a lado, y lo que cambia entre las dos es que las partes
/// estan corridas unas respecto de otras: el icono desplazado, el badge
/// empujado hacia atras, el subrayado desfasado. Un `Matrix4` sobre el hijo
/// completo inclina todo junto, que es exactamente lo que el estudio descarta.
///
/// **No se aplica a texto.** El logo de la referencia es frontal, y desfasar
/// las partes de una palabra la vuelve ilegible.
///
/// Las partes van **de atras hacia adelante**: la primera de la lista es la que
/// queda al fondo, sin desfase.
///
/// ```dart
/// Perspective(
///   children: [placa, icono, badge],
/// )
/// ```
///
/// **Cada parte entra al arbol una sola vez**, aun con [shadow] en `true`: la
/// sombra se pinta desde un render object propio, asi que no hay copia, no hay
/// `State` duplicado y una parte puede llevar un `GlobalKey`.
///
/// **Si el subarbol de una parte necesita compositing** se pinta sin sombra.
class Perspective extends StatelessWidget {
  /// Apila las partes con un desfase acumulado y una sombra.
  const new({
    required this.children,
    super.key,
    this.stepOffset = const Offset(3, 2),
    this.shadow = true,
    this.shadowOpacity = 0.35,
    this.shadowBlur = 2,
  });

  /// Las partes, de atras hacia adelante.
  final List<Widget> children;

  /// Desfase que se acumula por capa.
  ///
  /// La parte `i` se desplaza `stepOffset * i`, asi que la primera queda en su
  /// lugar y cada siguiente se corre un paso mas.
  final Offset stepOffset;

  /// Si cada parte lleva su sombra.
  final bool shadow;

  /// Opacidad de la sombra, de 0 a 1.
  ///
  /// Se recorta al rango, igual que el `jitter` de los efectos de rafaga y el
  /// `bandWidth` del barrido: un `Color.withValues` fuera de `0..1` no lanza,
  /// deja un color invalido.
  final double shadowOpacity;

  /// Sigma del difuminado de la sombra.
  final double shadowBlur;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Stack(
      // Alignment y no AlignmentDirectional: el default de Stack resuelve
      // contra un Directionality —sin ancestro, performLayout revienta— y en
      // RTL alinearia las partes al borde derecho, corriendolas unas respecto
      // de otras cuando no miden lo mismo. El desfase de este widget ya es
      // absoluto: Offset(3, 2) es derecha y abajo en cualquier idioma.
      alignment: Alignment.topLeft,
      // El desfase no cambia el layout, asi que el Stack mide como la parte
      // mas grande y el default Clip.hardEdge recortaria justo lo desplazado.
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < children.length; i++)
          Transform.translate(
            offset: stepOffset * i.toDouble(),
            child: shadow
                ? _ShadowedPart(
                    shadowOffset: stepOffset,
                    opacity: shadowOpacity,
                    blur: shadowBlur,
                    child: children[i],
                  )
                : children[i],
          ),
      ],
    );
  }
}

/// Una parte con su sombra debajo: la misma parte, negra y difuminada.
class _ShadowedPart extends SingleChildRenderObjectWidget {
  const new({
    required this.shadowOffset,
    required this.opacity,
    required this.blur,
    required super.child,
  });

  final Offset shadowOffset;
  final double opacity;
  final double blur;

  @override
  RenderShadowedPart createRenderObject(BuildContext context) =>
      RenderShadowedPart(
        shadowOffset: shadowOffset,
        opacity: opacity,
        blur: blur,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderShadowedPart renderObject,
  ) {
    renderObject
      ..shadowOffset = shadowOffset
      ..opacity = opacity
      ..blur = blur;
  }
}
