/// Sistema de carga y revelado por capas para Flutter, con el lenguaje visual
/// de un HUD holográfico.
///
/// Cinco familias. Las **capas** —`BlockNoise`, `DotMatrix`, `TechFrame`,
/// `GuideLines`— pintan y no tienen reloj propio: aceptan un `progress`
/// externo opcional y sin él son estáticas. Las de **ritmo** —`ChromaticBurst`,
/// `SlicedBox`, `NoiseSweep`, `TerminalCursor`— sí lo tienen y sirven sueltas
/// en bucle. Las de **entrada** —`ExpandLine`, `Stagger`— gobiernan cómo
/// aparece algo. El **modificador** `Perspective` desfasa las partes de su
/// hijo. Y el **orquestador** `NeuronReveal` corre las fases en orden y les
/// mueve el `progress` a las capas.
///
/// Se combinan **anidándolos**. No hay un widget con banderas ni un enum de
/// efectos: cada archivo hace una cosa y se testea solo, sin matriz de
/// combinaciones.
///
/// `ExpandLine`, `Perspective` y `Stagger` no tienen consumidor obligatorio y
/// eso no las vuelve código muerto: son las tres piezas que el sistema necesita
/// para cubrir su vocabulario completo —la apertura desde una línea, el
/// movimiento que sale del plano, y el escalonado entre hermanos—, y las tres
/// están cubiertas por sus tests.
library;

export 'src/astral_defaults.dart';
export 'src/block_noise.dart';
export 'src/chromatic_burst.dart';
export 'src/dot_matrix.dart';
export 'src/expand_line.dart';
export 'src/guide_lines.dart';
export 'src/neuron_corner_drift.dart';
export 'src/neuron_guide_drift.dart';
export 'src/neuron_registry.dart';
export 'src/neuron_reveal.dart';
export 'src/neuron_reveal_memory.dart';
export 'src/neuron_sweep_period.dart';
export 'src/neuron_timeline.dart';
export 'src/noise_sweep.dart';
export 'src/perspective.dart';
export 'src/sliced_box.dart';
export 'src/stagger.dart';
export 'src/tech_frame.dart';
export 'src/terminal_cursor.dart';
