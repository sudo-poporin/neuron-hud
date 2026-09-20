part of 'chromatic_burst.dart';

/// Pinta el hijo de [ChromaticBurst] tres veces sin reinsertarlo en el arbol.
///
/// **Es publico solo para que los tests tengan un observable.** La pintura no
/// deja rastro en el arbol de widgets, asi que sin esto no hay forma barata de
/// aseverar que hay rafaga: la alternativa es rasterizar un frame, medida en
/// ~19 veces el costo de leer un campo.
@visibleForTesting
class RenderChromaticBurst extends RenderProxyBox {
  /// Pinta el hijo de [ChromaticBurst] tres veces sin reinsertarlo en el arbol.
  new({
    required this._amount,
    required this._offset,
    required this._tilt,
    required this._colorA,
    required this._colorB,
    required this._blendMode,
  });

  double _amount;
  double _offset;
  double _tilt;
  Color _colorA;
  Color _colorB;
  BlendMode _blendMode;

  /// Cuanto pesa la rafaga ahora, de 0 a 1.
  ///
  /// En 0 el hijo se pinta pelado, sin fantasmas. Es `sin(t * pi)`, asi que el
  /// maximo cae en la mitad de la rafaga: es el PICO de la referencia, no una
  /// rampa.
  double get amount => _amount;

  set amount(double value) {
    if (value == _amount) return;

    _amount = value;
    markNeedsPaint();
  }

  /// Desplazamiento maximo en X de cada fantasma, en pixeles logicos.
  double get offset => _offset;

  set offset(double value) {
    if (value == _offset) return;

    _offset = value;
    markNeedsPaint();
  }

  /// Direccion del eje del desfase, en radianes.
  ///
  /// En 0 los fantasmas se corren horizontal puro y [colorA] queda a la
  /// izquierda, como en la referencia. Pasada media vuelta los dos colores
  /// quedan cambiados de lado.
  ///
  /// Se sortea por rafaga, no por frame: un angulo nuevo en cada frame haria
  /// vibrar el eje en vez de inclinarlo.
  double get tilt => _tilt;

  set tilt(double value) {
    if (value == _tilt) return;

    _tilt = value;
    markNeedsPaint();
  }

  /// Color de la capa que se corre a la izquierda.
  Color get colorA => _colorA;

  set colorA(Color value) {
    if (value == _colorA) return;

    _colorA = value;
    markNeedsPaint();
  }

  /// Color de la capa que se corre a la derecha.
  Color get colorB => _colorB;

  set colorB(Color value) {
    if (value == _colorB) return;

    _colorB = value;
    markNeedsPaint();
  }

  /// Como se componen los fantasmas contra el fondo.
  BlendMode get blendMode => _blendMode;

  set blendMode(BlendMode value) {
    if (value == _blendMode) return;

    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Sin guarda de `child == null`: el hijo es `required` y no anulable, asi
    // que la rama seria inalcanzable y romperia el 100 % de cobertura.
    final child = this.child!;

    // `needsCompositing` y no `child.isRepaintBoundary`: el primero ya viene
    // calculado sobre el subarbol entero, asi que atrapa un `Opacity` con alpha
    // intermedio tres niveles abajo, un `ColorFiltered` o una platform view.
    //
    // Repintar un subarbol que retiene un handle de capa no la duplica: la
    // **muda**, porque `PaintingContext.appendLayer` arranca con
    // `layer.remove()`. Los fantasmas saldrian invisibles. Saltearlos deja «el
    // efecto no se ve», que para decoracion es la falla correcta.
    if (_amount <= 0 || needsCompositing) {
      context.paintChild(child, offset);

      return;
    }

    // El desfase deja de ser puro en X: el eje apunta a `_tilt`. Los dos
    // fantasmas siguen siendo opuestos —uno a `tilt`, el otro a `tilt + 180`—,
    // y de que lado cae cada color sale de si `_tilt` paso o no de media
    // vuelta, que es lo que sortea `_tiltForBurst`.
    final shift = _offset * _amount;
    final axis = Offset(math.cos(_tilt), math.sin(_tilt)) * shift;

    _paintGhost(context, offset, child, -axis, _colorA);
    _paintGhost(context, offset, child, axis, _colorB);
    context.paintChild(child, offset);
  }

  void _paintGhost(
    PaintingContext context,
    Offset offset,
    RenderBox child,
    Offset delta,
    Color color,
  ) {
    // `context.canvas` se lee fresco en cada uso y **nunca** se guarda en una
    // variable local. Cachearlo revienta con `Bad state: A Dart object
    // attempted to access a native peer` en cuanto el hijo compone:
    // `paintChild` llama `stopRecordingIfNeeded()` y el canvas viejo queda
    // muerto. Verificado.
    context.canvas
      ..save()
      ..translate(delta.dx, delta.dy)
      ..saveLayer(
        // Bounds nulos: `offset & size` recortaria el desborde del hijo, y las
        // capas de este package desbordan a proposito.
        null,
        // El tinte viaja en el `Paint` del `saveLayer` y **no** en un
        // `ColorFiltered` adentro. Un `ColorFiltered` declara
        // `alwaysNeedsCompositing` y pinta por `pushColorFilter`, que corta la
        // grabacion del canvas: el `restore()` cae sobre un canvas nuevo y el
        // `Paint` termina aplicado a una capa vacia, asi que el hijo se compone
        // con `srcOver`. Medido con captura de pixeles sobre fondo rojo con
        // fantasma cian y `plus`: con el tinte adentro daba `0xFF00FFFF`,
        // identico a no tener blend; con el tinte aca, da `0xFFFFFFFF`.
        Paint()
          ..blendMode = _blendMode
          // srcIn deja la silueta del hijo con el color pleno: es el frame del
          // pico de la referencia, donde el wordmark es blanco.
          ..colorFilter = ColorFilter.mode(
            color.withValues(alpha: color.a * _amount),
            BlendMode.srcIn,
          ),
      );
    context.paintChild(child, offset);
    context.canvas
      ..restore()
      ..restore();
  }
}
