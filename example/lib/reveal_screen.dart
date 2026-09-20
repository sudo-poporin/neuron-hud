import 'package:example/demo_section.dart';
import 'package:example/periodic_tick.dart';
import 'package:flutter/material.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Las fases de un revelado de texto: la lista completa **sin
/// [NeuronPhase.slice]**.
///
/// **El package no publica esta lista**, y es la más fácil de olvidar: el
/// default de `NeuronReveal` son las siete, así que un texto revelado sin
/// pensarlo sale con slicing encima. El slicing es adorno de estabilización y
/// viene *después* de que el contenido ya se leyó; sobre un mensaje lo vuelve
/// ilegible justo mientras se lo está leyendo.
const textPhases = <NeuronPhase>[
  NeuronPhase.guides,
  NeuronPhase.dots,
  NeuronPhase.noise,
  NeuronPhase.condense,
  NeuronPhase.chromatic,
  NeuronPhase.settle,
];

/// Cada cuánto vuelve a correr el revelado.
///
/// Las siete fases suman 830 ms y las seis del texto 740, así que el período
/// tiene que ser más largo o el revelado se corta a sí mismo: se mide del
/// arranque de un ciclo al del siguiente, no acumulado.
const _replayPeriod = Duration(milliseconds: 2200);

/// El rol **entrada**: un revelado que tiene principio y fin.
///
/// `NeuronReveal` corre las siete fases de [NeuronPhase] en orden —`guides`,
/// `dots` y `noise` levantan el andamio; `condense`, `chromatic`, `slice` y
/// `settle` lo resuelven— moviéndole el `progress` a las capas y montando las
/// dos piezas de ráfaga en la suya.
///
/// **A diferencia del rol ausente, termina.** Por eso acá hay un reloj que lo
/// vuelve a correr: no es parte del efecto, es lo que permite mirarlo dos
/// veces.
class RevealScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  /// Cuántas veces se pidió el revelado a mano.
  ///
  /// Va en la `key` junto con el tick del reloj: `NeuronReveal` corre su
  /// timeline en `initState` y no sabe rebobinar, así que la única forma de
  /// volver a correrlo es remontarlo.
  int _manual = 0;

  @override
  Widget build(BuildContext context) {
    return PeriodicTick(
      period: _replayPeriod,
      builder: (context, tick) {
        final cycle = ValueKey('$tick-$_manual');

        return Column(
          children: [
            DemoSection(
              title: 'CON SLICE — UNA FIGURA',
              caption:
                  'Las siete fases. Después del pico de aberración cromática '
                  'llegan las bandas horizontales corridas, que es lo que '
                  'estabiliza la pieza.',
              child: NeuronReveal(
                key: cycle,
                seed: 3,
                child: const FlutterLogo(size: 150),
              ),
            ),
            DemoSection(
              title: 'SIN SLICE — UN TEXTO',
              caption:
                  'Las mismas fases menos `slice`. El desfase cromático va en '
                  'píxeles y no en fracción, así que sobre un texto de pantalla '
                  'hay que subirlo para que se lea.',
              child: NeuronReveal(
                key: cycle,
                phases: textPhases,
                chromaticOffset: 20,
                seed: 5,
                child: const Text(
                  'CARGANDO DATOS',
                  style: TextStyle(
                    color: astralInk,
                    fontSize: 26,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton.icon(
                onPressed: () => setState(() => _manual++),
                icon: const Icon(Icons.replay),
                label: const Text('CORRER AHORA'),
              ),
            ),
          ],
        );
      },
    );
  }
}
