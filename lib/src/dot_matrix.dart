import 'package:flutter/widgets.dart';
import 'package:neuron_hud/src/astral_defaults.dart';

/// Matriz regular de puntos sobre el hijo.
///
/// Es la capa ドット del diagrama de descomposicion del HUD de Astral Chain, y
/// da la textura de fondo mientras el elemento se forma.
///
/// **Es transitoria, no un fondo permanente.** En `hud_inanimation.mp4` —el
/// video del blog oficial de PlatinumGames en
/// https://www.platinumgames.com/official-blog/article/10397— la matriz esta
/// durante la formacion y se va cuando el elemento resuelve: con [progress]
/// en 1 no pinta nada.
///
/// **Con `child` en null no pinta nada.** `CustomPaint` sin hijo se dimensiona
/// por su parametro `size`, que por defecto es `Size.zero`.
class DotMatrix extends StatelessWidget {
  /// Matriz regular de puntos sobre el hijo.
  const new({
    super.key,
    this.spacing = 8,
    this.dotRadius = 0.75,
    this.color = astralInkFaint,
    this.progress,
    this.child,
  });

  /// Distancia entre puntos, en pixeles logicos.
  final double spacing;

  /// Radio de cada punto.
  final double dotRadius;

  /// Color de los puntos.
  final Color color;

  /// Cuanto resolvio el elemento, de 0 a 1.
  ///
  /// `null` y 0 pintan la matriz completa; 1 no pinta nada. Es la polaridad
  /// **inversa** a `HoldProgressBorderPainter`, donde 0 no pinta nada y 1
  /// pinta el perimetro completo: un orquestador que maneje las dos capas
  /// desde el mismo `AnimationController` va a invertir una animacion en
  /// silencio si no lo tiene en cuenta.
  final double? progress;

  /// Contenido sobre el que se dibuja la matriz.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DotMatrixPainter(
        spacing: spacing,
        dotRadius: dotRadius,
        color: color,
        progress: progress,
      ),
      child: child,
    );
  }
}

/// Pinta la matriz de [DotMatrix].
class DotMatrixPainter extends CustomPainter {
  /// Pinta la matriz de [DotMatrix].
  const new({
    required this.spacing,
    required this.dotRadius,
    required this.color,
    required this.progress,
  });

  /// Distancia entre puntos.
  final double spacing;

  /// Radio de cada punto.
  final double dotRadius;

  /// Color de los puntos.
  final Color color;

  /// Cuanto resolvio el elemento, de 0 a 1.
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final remaining = (1 - (progress ?? 0)).clamp(0.0, 1.0);
    if (remaining <= 0) return;
    if (spacing <= 0) return;

    final paint = Paint()..color = color.withValues(alpha: color.a * remaining);

    // Medio spacing de margen para que la matriz quede centrada en la caja en
    // vez de pegada al borde superior izquierdo.
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotMatrixPainter oldDelegate) =>
      oldDelegate.spacing != spacing ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress;
}
