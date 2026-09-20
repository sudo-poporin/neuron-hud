part of 'neuron_reveal.dart';

/// Pinta el hijo de [_ContentOpacity] atenuado, sin capa cuando es opaco.
///
/// **Es publico solo para que los tests tengan un observable**, igual que los
/// render objects de los efectos: `_ContentOpacity` es privado y la opacidad
/// del contenido ya no es un widget que se pueda buscar por tipo.
@visibleForTesting
class RenderContentOpacity extends RenderProxyBox {
  /// Aplica una opacidad al contenido sin componer cuando es opaco.
  new(this._opacity);

  double _opacity;

  /// Cuanto se ve el contenido, de 0 a 1.
  double get opacity => _opacity;

  set opacity(double value) {
    if (value == _opacity) return;

    final wasVisible = _opacity > 0;
    _opacity = value;
    markNeedsPaint();

    // Igual que `RenderOpacity`: si cambia si el contenido se anuncia o no, hay
    // que marcar la semantica. Sin esto el arbol queda con el parentData sucio
    // y salta `!semantics.parentDataDirty`.
    if (wasVisible != (_opacity > 0)) markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Sin guarda de `child == null`: el hijo del orquestador es `required` y no
    // anulable.
    final child = this.child!;
    final alpha = (_opacity.clamp(0.0, 1.0) * 255).round();

    // Invisible: no se pinta nada, igual que `RenderOpacity` con alpha 0.
    if (alpha == 0) return;

    // Opaco: el hijo va directo al canvas, sin capa. Es el caso que ocupa casi
    // todo el revelado, y el unico que los burst necesitan.
    if (alpha == 255) {
      context.paintChild(child, offset);

      return;
    }

    // Bounds nulos: las capas de esta carpeta desbordan a proposito.
    context.canvas.saveLayer(
      null,
      Paint()..color = Color.fromARGB(alpha, 0, 0, 0),
    );
    context.paintChild(child, offset);
    context.canvas.restore();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // Invisible no se anuncia, que es lo que hacia el `Opacity` de antes.
    if (_opacity > 0) super.visitChildrenForSemantics(visitor);
  }
}
