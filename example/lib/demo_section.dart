import 'package:flutter/material.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Un efecto aislado, con su nombre y una linea de explicacion.
///
/// Cada seccion muestra **una sola cosa**. Es lo que permite capturar un GIF
/// corto de un efecto sin que un vecino entre en cuadro.
class DemoSection extends StatelessWidget {
  const new({
    required this.title,
    required this.caption,
    required this.child,
    super.key,
  });

  /// Que pieza del package corre acá.
  final String title;

  /// Por que esta acá, en una linea.
  final String caption;

  /// El efecto.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: astralInk,
              fontSize: 13,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
              color: astralInkDim,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Center(child: child),
        ],
      ),
    );
  }
}
