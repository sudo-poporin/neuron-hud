part of 'sliced_box.dart';

/// Pinta el hijo de [SlicedBox] una vez por banda, sin reinsertarlo.
///
/// **Es publico solo para que los tests tengan un observable**, igual que
/// `RenderChromaticBurst`: la pintura no deja rastro en el arbol de widgets.
@visibleForTesting
class RenderSlicedBox extends RenderProxyBox {
  /// Pinta el hijo de [SlicedBox] una vez por banda, sin reinsertarlo.
  new({
    required this._slices,
    required this._sliceOffset,
    required this._direction,
    required this._streaks,
    required this._streakColor,
    required this._streakOverflow,
    required this._streakStrokeWidth,
  });

  List<SlicedBand> _slices;
  double _sliceOffset;
  double _direction;
  bool _streaks;
  Color _streakColor;
  double _streakOverflow;
  double _streakStrokeWidth;

  /// Las bandas de la rafaga en curso. Vacia en reposo.
  List<SlicedBand> get slices => _slices;

  set slices(List<SlicedBand> value) {
    // listEquals y no identidad: la lista se arma de nuevo en cada frame.
    if (listEquals(value, _slices)) return;

    _slices = value;
    markNeedsPaint();
  }

  /// Desplazamiento maximo en X de una banda, en pixeles logicos.
  double get sliceOffset => _sliceOffset;

  set sliceOffset(double value) {
    if (value == _sliceOffset) return;

    _sliceOffset = value;
    markNeedsPaint();
  }

  /// Sentido del corrimiento en el subpaso actual: 1 o -1.
  double get direction => _direction;

  set direction(double value) {
    if (value == _direction) return;

    _direction = value;
    markNeedsPaint();
  }

  /// Si se pintan las lineas largas hacia los lados.
  bool get streaks => _streaks;

  set streaks(bool value) {
    if (value == _streaks) return;

    _streaks = value;
    markNeedsPaint();
  }

  /// Color de los streaks.
  Color get streakColor => _streakColor;

  set streakColor(Color value) {
    if (value == _streakColor) return;

    _streakColor = value;
    markNeedsPaint();
  }

  /// Pixeles que los streaks se extienden mas alla de la caja.
  double get streakOverflow => _streakOverflow;

  set streakOverflow(double value) {
    if (value == _streakOverflow) return;

    _streakOverflow = value;
    markNeedsPaint();
  }

  /// Ancho del trazo de los streaks.
  double get streakStrokeWidth => _streakStrokeWidth;

  set streakStrokeWidth(double value) {
    if (value == _streakStrokeWidth) return;

    _streakStrokeWidth = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Sin guarda de `child == null`: el hijo es `required` y no anulable, asi
    // que la rama seria inalcanzable y romperia el 100 % de cobertura.
    final child = this.child!;

    // El hijo base primero, las bandas encima. Es el orden del Stack de antes.
    context.paintChild(child, offset);

    // Misma guarda que ChromaticBurst, y por lo mismo: repintar un subarbol que
    // retiene un handle de capa la muda en vez de duplicarla, porque
    // `PaintingContext.appendLayer` arranca con `layer.remove()`.
    if (_slices.isNotEmpty && !needsCompositing) {
      for (final slice in _slices) {
        // `context.canvas` fresco en cada uso, nunca en una variable local: si
        // el hijo compusiera, `paintChild` cortaria la grabacion y el
        // `restore()` caeria sobre un canvas muerto.
        context.canvas
          ..save()
          // La banda queda quieta y su contenido se corre: eso es el slicing.
          // Una franja pintada encima seria mas barata pero no es lo mismo.
          ..clipRect(
            Rect.fromLTWH(
              offset.dx,
              offset.dy + slice.top * size.height,
              size.width,
              slice.height * size.height,
            ),
          )
          ..translate(slice.shift * _sliceOffset * _direction, 0);
        context.paintChild(child, offset);
        context.canvas.restore();
      }
    }

    // Los streaks quedan **fuera** de la guarda a proposito: no repintan al
    // hijo, asi que no tienen el problema de la capa. Un hijo que compone capa
    // pierde las bandas y conserva las lineas, que es la degradacion mas fiel
    // — los streaks son la parte que se lee de lejos.
    if (_streaks && _slices.isNotEmpty) {
      context.canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      SlicedStreaksPainter(
        bands: [
          for (final slice in _slices) (top: slice.top, height: slice.height),
        ],
        color: _streakColor,
        overflow: _streakOverflow,
        strokeWidth: _streakStrokeWidth,
      ).paint(context.canvas, size);
      context.canvas.restore();
    }
  }
}
