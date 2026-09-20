import 'package:example/demo_section.dart';
import 'package:example/periodic_tick.dart';
import 'package:flutter/material.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Opacidad de las capas de estructura: las guías y el barrido.
///
/// Más fuerte que esto, el andamio compite con el contenido al que le sirve de
/// referencia.
const _structureAlpha = 0.3;

/// Opacidad de las capas de detalle: el marco, el ruido y los puntos.
const _detailAlpha = 0.2;

/// El rol **ausente**: contenido que todavía no resolvió.
///
/// Es el único de los tres roles que **no termina nunca**, y el único que no se
/// arma con una pieza sola: son las cuatro capas apiladas más tres relojes
/// externos que las mueven. Las capas no tienen reloj propio —derivan su layout
/// de sus parámetros y no se mueven solas—, así que sin esos relojes la caja
/// queda quieta y lee como una textura.
class AbsentScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        DemoSection(
          title: 'LA CAJA ESQUELETO',
          caption:
              'Las cuatro capas en el orden del diagrama: las guías afuera, '
              'después el marco, después el ruido, los puntos al fondo. Tres '
              'relojes externos las mueven, y cada uno corre a su escala: el '
              'ruido varias veces por segundo, el barrido cada tres, las guías '
              'cada cuatro. Al mismo ritmo se leerían como una sola cosa '
              'parpadeando.',
          child: SkeletonBox(width: 220, height: 300, seed: 7),
        ),
        DemoSection(
          title: 'TRES CAJAS, TRES SEMILLAS',
          caption:
              'La semilla decide el layout de cada capa y el desfase de cada '
              'reloj. Tres cajas vecinas con la misma semilla laten juntas, que '
              'lee como si la pantalla temblara; con semillas distintas cada '
              'una espera por su cuenta.',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonBox(width: 76, height: 108, seed: 1),
              SizedBox(width: 12),
              SkeletonBox(width: 76, height: 108, seed: 2),
              SizedBox(width: 12),
              SkeletonBox(width: 76, height: 108, seed: 3),
            ],
          ),
        ),
      ],
    );
  }
}

/// Las cuatro capas del HUD apiladas, con sus tres relojes.
///
/// **No hay un preset de esto en el package**, y armarlo es lo que muestra el
/// reparto del sistema: las capas pintan, y quien las mueve es un widget
/// aparte.
class SkeletonBox extends StatelessWidget {
  const new({
    required this.width,
    required this.height,
    super.key,
    this.ink = astralInk,
    this.seed = 0,
  });

  /// Ancho de la caja.
  final double width;

  /// Alto de la caja.
  final double height;

  /// Color base de las capas.
  ///
  /// La alpha de lo que se pase se ignora: cada capa aplica la suya, que es lo
  /// que las separa entre sí.
  final Color ink;

  /// Semilla del layout de las capas y del desfase de los tres relojes.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final structure = ink.withValues(alpha: _structureAlpha);
    final detail = ink.withValues(alpha: _detailAlpha);

    return NoiseSweep(
      color: structure,
      bandWidth: 0.05,
      trail: 0.55,
      wispCount: 2,
      period: neuronSweepPeriod(seed),
      seed: seed,
      child: NeuronGuideDrift(
        amplitude: neuronGuideDriftAmplitude,
        period: neuronGuideDriftPeriod(seed),
        builder: (context, drift) => GuideLines(
          color: structure,
          drift: drift,
          seed: seed,
          child: NeuronCornerDrift(
            amplitude: neuronCornerDriftAmplitude,
            period: neuronCornerDriftPeriod(seed),
            mode: NeuronCornerDriftMode.combined,
            seed: seed,
            builder: (context, corners) => TechFrame(
              color: detail,
              cornerOffsets: corners,
              // **El package no publica este reloj**, y es el que le falta al
              // rol ausente: `BlockNoise` deriva su layout de la semilla y es
              // `const`, así que sin alguien que se la cambie el campo de
              // barras queda fijo. Los otros tres relojes de la caja
              // —`NeuronGuideDrift`, `NeuronCornerDrift` y el `repeat` interno
              // de `NoiseSweep`— sí están.
              child: PeriodicTick(
                period: _noisePeriod(seed),
                builder: (context, tick) => BlockNoise(
                  // Menos denso que el default de 0,35: a esa densidad el
                  // campo de barras tapa a las otras tres capas, y esta
                  // pantalla existe para que se vean las cuatro.
                  density: 0.18,
                  color: detail,
                  seed: seed + tick,
                  child: DotMatrix(
                    color: detail,
                    child: SizedBox(width: width, height: height),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cada cuánto se recalcula el campo de barras: entre cinco y once veces por
/// segundo, desfasado por la semilla.
///
/// Es el más rápido de los tres relojes de la caja, y tiene que serlo: el ruido
/// es lo que dice «esto todavía no resolvió», y el andamio que le sirve de
/// referencia no puede moverse a su ritmo.
Duration _noisePeriod(int seed) => Duration(milliseconds: 90 + (seed % 5) * 25);
