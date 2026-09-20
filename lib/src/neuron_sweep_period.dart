/// Periodo del barrido, desfasado por la semilla.
///
/// `NoiseSweep` arranca su reloj con `repeat()` desde 0 y **no** desfasa por
/// semilla: la semilla solo alimenta el layout de los jirones del painter.
/// Veinte cajas montadas en el mismo frame laten en fase, que lee como parpadeo
/// y no como carga. Correrles el periodo las separa sin coordinar nada entre
/// ellas.
///
/// El `%` de Dart sobre enteros devuelve siempre un valor no negativo, asi que
/// una semilla negativa no se sale del rango.
///
/// **Vive acá y no en el esqueleto que lo usa** porque el invariante que
/// importa es entre los tres periodos del sistema: las guias tienen que ser mas
/// lentas que el barrido, que tiene que ser mas lento que el ruido. Tres capas
/// al mismo ritmo se leen como una sola cosa parpadeando. Con los tres en el
/// mismo lugar ese invariante se puede testear; repartidos, no.
Duration neuronSweepPeriod(int seed) =>
    Duration(milliseconds: 2800 + (seed % 8) * 90);
