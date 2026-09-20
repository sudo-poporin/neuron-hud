import 'package:example/demo_section.dart';
import 'package:flutter/material.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// El rol **en curso**: algo está pasando ahora.
///
/// Es el único de los tres que no necesita nada alrededor. Estas piezas tienen
/// reloj propio y sirven sueltas, en bucle: no hay orquestador, no hay `key`
/// que remontar y no hay un reloj externo que las mueva.
///
/// **Lo que comunica «esto está pasando» es que sea continuo.** Una ráfaga cada
/// tres segundos comunica inestabilidad, no progreso.
class BusyScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DemoSection(
          title: 'NOISE SWEEP — SOBRE UN ÍCONO',
          caption:
              'Modo `progress`: una banda con cabeza y cola atraviesa la pieza. '
              'La estela es lo que la lee como algo que pasó por ahí en vez de '
              'como una franja que se traslada.',
          child: NoiseSweep(
            trail: 0.55,
            bandWidth: 0.12,
            child: Icon(Icons.cloud_download, size: 96, color: astralInk),
          ),
        ),
        DemoSection(
          title: 'NOISE SWEEP — MODO AMBIENTE',
          caption:
              'Jirones sueltos derivando sobre todo el plano. Es ambiente y no '
              'señal: no sirve solo para avisar que algo está pasando.',
          child: Container(
            width: 240,
            height: 110,
            decoration: BoxDecoration(
              border: Border.all(color: astralInkFaint),
            ),
            child: const NoiseSweep(
              mode: NoiseSweepMode.ambient,
              wispCount: 8,
              child: SizedBox.expand(),
            ),
          ),
        ),
        const DemoSection(
          title: 'TERMINAL CURSOR',
          caption:
              'Un glifo que parpadea al final del contenido. Es el más barato '
              'del set: un `Timer` que alterna un `Opacity`, sin controller y '
              'sin un vsync por frame. El ancho no cambia entre prendido y '
              'apagado, así que el label no salta.',
          child: TerminalCursor(
            style: TextStyle(color: astralChromaticA, fontSize: 22),
            child: Text(
              'BUSCANDO',
              style: TextStyle(
                color: astralInk,
                fontSize: 22,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const DemoSection(
          title: 'CHROMATIC BURST',
          caption:
              'El pico de aberración: cian a la izquierda, rojo a la derecha. '
              'Con `period` dispara en bucle; sin él, una sola vez y nunca más. '
              'Entre ráfagas el hijo no tiene ni una copia extra en el árbol.',
          child: ChromaticBurst(
            period: Duration(milliseconds: 1400),
            offset: 10,
            child: Text(
              'NEURON',
              style: TextStyle(
                color: astralInk,
                fontSize: 34,
                letterSpacing: 6,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
        const DemoSection(
          title: 'SLICED BOX',
          caption:
              'Bandas horizontales desplazadas, en ráfaga. Desplaza contenido '
              'real: cada banda repinta al hijo recortado y corrido. Una franja '
              'pintada encima sería más barata pero no sería slicing.',
          child: SlicedBox(
            period: Duration(milliseconds: 1400),
            child: Text(
              'NEURON',
              style: TextStyle(
                color: astralInk,
                fontSize: 34,
                letterSpacing: 6,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
