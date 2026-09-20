part of 'perspective.dart';

/// Pinta la parte dos veces —su sombra y ella— sin reinsertarla en el arbol.
///
/// **Es publico solo para que los tests tengan un observable**, igual que los
/// render objects de los dos efectos de rafaga: la pintura no deja rastro en el
/// arbol de widgets.
@visibleForTesting
class RenderShadowedPart extends RenderProxyBox {
  /// Pinta la parte dos veces sin reinsertarla en el arbol.
  new({
    required this._enabled,
    required this._shadowOffset,
    required this._opacity,
    required this._blur,
  });

  bool _enabled;
  Offset _shadowOffset;
  double _opacity;
  double _blur;

  /// Si la pasada de sombra corre.
  ///
  /// **Es un flag y no un widget que se saca del arbol.** Alternar entre
  /// envolver a la parte y pasarla pelada le cambia el ancestro inmediato, y
  /// Flutter reconcilia por posicion y tipo: desmonta el subarbol y una parte
  /// con estado lo pierde.
  bool get enabled => _enabled;

  set enabled(bool value) {
    if (value == _enabled) return;

    _enabled = value;
    markNeedsPaint();
  }

  /// Cuanto se corre la sombra respecto de su parte.
  Offset get shadowOffset => _shadowOffset;

  set shadowOffset(Offset value) {
    if (value == _shadowOffset) return;

    _shadowOffset = value;
    markNeedsPaint();
  }

  /// Opacidad de la sombra, de 0 a 1.
  double get opacity => _opacity;

  set opacity(double value) {
    if (value == _opacity) return;

    _opacity = value;
    markNeedsPaint();
  }

  /// Sigma del difuminado de la sombra.
  double get blur => _blur;

  set blur(double value) {
    if (value == _blur) return;

    _blur = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Sin guarda de `child == null`: la parte es `required` y no anulable, asi
    // que la rama seria inalcanzable y romperia el 100 % de cobertura.
    final child = this.child!;

    if (!_enabled) {
      context.paintChild(child, offset);

      return;
    }

    // Misma guarda que los dos efectos de rafaga, y por lo mismo: repintar un
    // subarbol que retiene un handle de capa la muda en vez de duplicarla,
    // porque `PaintingContext.appendLayer` arranca con `layer.remove()`.
    if (!needsCompositing) {
      // `context.canvas` fresco en cada uso, nunca en una variable local: si la
      // parte compusiera, `paintChild` cortaria la grabacion y el `restore()`
      // caeria sobre un canvas muerto.
      context.canvas
        ..save()
        ..translate(_shadowOffset.dx, _shadowOffset.dy)
        ..saveLayer(
          // Bounds nulos: el blur desborda la caja de la parte a proposito.
          null,
          // El blur y el tinte van los dos en el `Paint` del `saveLayer`. Antes
          // eran un `ImageFiltered` sobre un `ColorFiltered`, y los dos fuerzan
          // capa: esto ahorra las dos.
          //
          // srcIn respeta la forma real de la parte: la sombra de un icono es
          // la del icono, no la de su caja. Un BoxShadow seria gratis pero
          // pondria una mancha rectangular que la referencia no tiene.
          Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: _blur, sigmaY: _blur)
            ..colorFilter = ColorFilter.mode(
              const Color(0xFF000000)
                  .withValues(alpha: _opacity.clamp(0.0, 1.0)),
              BlendMode.srcIn,
            ),
        );
      context.paintChild(child, offset);
      context.canvas
        ..restore()
        ..restore();
    }

    context.paintChild(child, offset);
  }
}
