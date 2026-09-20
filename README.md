# neuron_hud

Sistema de carga y revelado por capas para Flutter, con el lenguaje visual de un
HUD holográfico: ruido en bloques, matrices de puntos, marcos en L, líneas guía,
aberración cromática y bandas desplazadas.

Sin dependencias de terceros: sólo `flutter`.

## Instalación

Se consume por tag de git.

```yaml
dependencies:
  neuron_hud:
    git:
      url: https://github.com/sudo-poporin/neuron-hud
      ref: v1.0.0
```

```dart
import 'package:neuron_hud/neuron_hud.dart';
```

`lib/neuron_hud.dart` es el único punto de entrada. Nada de `lib/src/` se importa
por su path.

## El revelado

`NeuronReveal` es el orquestador: corre las siete fases en orden sobre su hijo y
les mueve el `progress` a las capas.

```dart
NeuronReveal(
  ready: cover != null,
  seed: item.id,
  ink: Colors.white,
  fastPathAfter: const Duration(milliseconds: 80),
  child: cover ?? const SizedBox.shrink(),
)
```

Con `ready: false` la **formación** corre igual y el revelado se detiene donde
empieza la **resolución**, con el andamio puesto y el contenido oculto. Cuando
pasa a `true`, sigue.

Las siete fases, en orden, con su duración por defecto:

| Fase | Qué pinta | Default |
| --- | --- | --- |
| `guides` | Las líneas guía, que son andamio y llegan primero | 120 ms |
| `dots` | El campo de matriz de puntos | 100 ms |
| `noise` | El cúmulo de ruido en bloques | 120 ms |
| `condense` | El ruido condensándose en la forma, y el contenido apareciendo | 180 ms |
| `chromatic` | El pico de aberración cromática. Una sola vez | 120 ms |
| `slice` | Las bandas horizontales desplazadas. Posterior al pico, no simultáneo | 90 ms |
| `settle` | La estabilización | 120 ms |

Las siete suman 830 ms. `phases` dice **cuáles** corren, no en qué orden: el
orden es siempre el de `NeuronPhase.values`. Un revelado de texto sin `slice`
suma 740 ms. Con la lista vacía se pinta el hijo pelado.

`durations` sobreescribe una fase o varias sin tocar el resto.

## El vocabulario

Cinco familias. Se combinan **anidándolas**: no hay un widget con banderas ni un
enum de efectos.

### Capas

`CustomPainter` sin reloj propio. Aceptan un `progress` externo opcional y sin él
son estáticas.

| Pieza | Qué pinta |
| --- | --- |
| `BlockNoise` | El campo de barras que se recalcula. El efecto firma del sistema |
| `DotMatrix` | La retícula de puntos del fondo |
| `TechFrame` | El marco en L de las cuatro esquinas |
| `GuideLines` | Las líneas de andamio, que pueden desbordar la caja |

**`progress` va al revés de lo que parece.** En 0 la capa se pinta **completa** y
en 1 no se pinta nada. Una capa entra llevando su `progress` de 1 a 0 y sale
llevándolo de 0 a 1. Es la inversa de casi cualquier painter de progreso, así que
invertirlo no da error: da un efecto que corre al revés y se ve casi bien.

### Ritmo

Tienen reloj propio y sirven sueltas, en bucle.

| Pieza | Qué hace |
| --- | --- |
| `ChromaticBurst` | El pico de aberración cromática, en ráfagas |
| `SlicedBox` | Las bandas horizontales desplazadas |
| `NoiseSweep` | El barrido que atraviesa la caja, con estela |
| `TerminalCursor` | El cursor que parpadea al final de un texto |

### Entrada

| Pieza | Qué hace |
| --- | --- |
| `ExpandLine` | La apertura desde una línea |
| `Stagger` | El escalonado de la entrada entre hermanos |

`Stagger` coordina el desfase de entrada, nunca el reloj de cada efecto.

### Modificador

`Perspective` desfasa las partes de su hijo con sombra. **No** es un `Matrix4`
sobre el hijo entero.

### Orquestador

`NeuronReveal`, arriba.

## El registro de revelados

Evita que un `Hero` en vuelo o un `ListView.builder` reciclando filas re-disparen
un revelado que ya corrió.

```dart
final owner = neuronRowOwner('lista', item.id);
final key = neuronRevealKey(owner, 'portada');

return NeuronRevealMemory(
  owner: owner,
  child: NeuronReveal(
    alreadyRevealed: neuronAlreadyRevealed(key),
    onRevealStart: () => markNeuronRevealed(key),
    child: child,
  ),
);
```

`onRevealStart` se dispara en el frame en que el revelado **arranca**, no al
terminarlo: cuando un `Hero` vuela, Flutter reconstruye el hijo para el overlay y
ese `NeuronReveal` nuevo arranca en cero. Consultando el registro, la
reconstrucción ve el id y pinta el final.

**Corre en fase de build, así que no puede llamar `setState`.**

El registro es estado de librería. Si montás estos widgets en tus tests, vacialo
entre uno y otro desde tu propio `flutter_test_config.dart`, o las suites fallan
por orden de ejecución:

```dart
void testExecutable(FutureOr<void> Function() testMain) async {
  setUp(resetNeuronRegistry);
  await testMain();
}
```

Ese es el motivo por el que `resetNeuronRegistry` se exporta a pesar de llevar
`@visibleForTesting`.

## Colores y tipografía

**Un package no puede leer el tema de su consumidor**, así que los colores entran
por parámetro y hay un default `const` para cada uno: `astralInk`,
`astralInkDim`, `astralInkFaint` para las capas, `astralChromaticA` y
`astralChromaticB` para el pico.

Los defaults son blanco sobre fondo oscuro, que es el de la referencia. **Sobre
un fondo claro no se ven**: pasá la tinta que tu fondo pida.

Lo mismo con la tipografía. `TerminalCursor` hereda el `DefaultTextStyle` del
entorno si no le pasás uno.

## Reducir movimiento

Con `MediaQuery.disableAnimations` los efectos quedan estáticos, sin controller y
sin timers.

**No es opcional y no es una optimización.** Aberración cromática más parpadeo
rápido es un patrón fotosensible.

## Azar determinista

Todos los efectos usan azar en runtime, y todos lo derivan de una semilla que
entra por parámetro. Derivarla del item —`seed: item.id`— le da a cada fila su
propio patrón, y hace que los tests sean deterministas.

La semilla también desfasa los relojes: veinte cajas montadas en el mismo frame y
con el mismo período laten juntas, y eso lee como parpadeo y no como carga.

## Atribución

El lenguaje visual de este package es una lectura del HUD de *Astral Chain*
(PlatinumGames, 2019), a partir de dos notas del blog oficial del estudio sobre
el diseño de su UI y sobre la animación de su HUD.

Es un trabajo derivado e independiente. Este proyecto **no está afiliado a
Nintendo ni a PlatinumGames**, ni cuenta con su respaldo. *Astral Chain* es marca
de sus respectivos titulares.

## Licencia

MIT. Ver [LICENSE](LICENSE).
