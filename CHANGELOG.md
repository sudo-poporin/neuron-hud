# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
el versionado sigue [Semantic Versioning](https://semver.org/lang/es/).

## [No publicado]

### Interno

- App de ejemplo en `example/`: cinco tabs que cubren las cinco familias —los
  tres roles, el escalonado y el modificador—, cada efecto aislado y en bucle.
  No cambia nada de lo que el barrel exporta.

## [1.0.0] - 2026-09-19

Primera versión publicable. `lib/neuron_hud.dart` es el único punto de entrada y
lo que exporta es, desde acá, superficie pública sujeta a semver.

### Agregado

- **Capas**, `CustomPainter` sin reloj propio, con `progress` externo opcional:
  `BlockNoise`, `DotMatrix`, `TechFrame` y `GuideLines`. En `progress` 0 la capa
  se pinta completa y en 1 no se pinta nada, que es la inversa de lo que hace
  casi cualquier painter de progreso.
- **Ritmo**, con reloj propio y útiles sueltas en bucle: `ChromaticBurst`,
  `SlicedBox`, `NoiseSweep` y `TerminalCursor`.
- **Entrada**: `ExpandLine` para la apertura desde una línea y `Stagger` para el
  escalonado entre hermanos.
- **Modificador**: `Perspective`, que desfasa las partes de su hijo con sombra y
  no es un `Matrix4` sobre el hijo entero.
- **Orquestador**: `NeuronReveal`, que corre las siete fases de `NeuronPhase` en
  orden sobre su hijo y les mueve el `progress` a las capas. `ready` detiene el
  revelado entre la formación y la resolución; `phases` elige cuáles corren;
  `durations` sobreescribe las que haga falta; `fastPathAfter` lo saltea entero
  cuando el contenido llegó al instante.
- **Registro de revelados**: `neuronRevealKey`, `neuronRowOwner`,
  `neuronAlreadyRevealed`, `markNeuronRevealed`, `forgetNeuronRevealed` y el
  widget `NeuronRevealMemory`. Evita que un `Hero` en vuelo o un
  `ListView.builder` reciclando filas re-disparen un revelado que ya corrió.
  `resetNeuronRegistry` se exporta —a pesar de llevar `@visibleForTesting`— para
  que quien monte estos widgets en sus tests pueda vaciarlo entre uno y otro.
- **Línea de tiempo**: `NeuronTimeline`, `NeuronPhase`, `neuronPhaseDurations`,
  `NeuronPhaseWindow` y `NeuronFrame`.
- **Relojes del esqueleto**: `NeuronGuideDrift`, `NeuronCornerDrift`,
  `NeuronCornerDriftMode` y las constantes y períodos que los alimentan
  —`neuronGuideDriftAmplitude`, `neuronGuideDriftPeriod`,
  `neuronCornerDriftAmplitude`, `neuronCornerDriftPeriod`,
  `neuronSweepPeriod`—.
- **Colores por defecto**: `astralInk`, `astralInkDim`, `astralInkFaint`,
  `astralChromaticA` y `astralChromaticB`. Entran por parámetro en todas las
  piezas: un package no puede leer el tema de su consumidor.
- **Fallback de reducir movimiento** en todos los efectos. Con
  `MediaQuery.disableAnimations` quedan estáticos, sin controller y sin timers.

### Corregido

- El período de la deriva de las guías pasa de un piso de 3200 ms a uno de
  3440 ms. Con el anterior su rango se solapaba con el del barrido y el
  invariante del sistema —las guías más lentas que el barrido, el barrido más
  lento que el ruido— se daba vuelta en una de cada veinticuatro semillas. El
  desfase por semilla de los dos queda igual.

### Interno

- Los render objects `RenderChromaticBurst`, `RenderContentOpacity`,
  `RenderShadowedPart` y `RenderSlicedBox` **no** se exportan: son el cómo y no
  el qué, y sacarlos más adelante sería un cambio mayor de versión.
