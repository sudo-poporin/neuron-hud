import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

/// Configuración que `flutter test` corre antes del `main` de **cada** archivo.
///
/// Vacía el registro de revelados entre tests. Resolverlo con un
/// `setUp(resetNeuronRegistry)` repetido en cada archivo cubre lo que hay hoy
/// pero no lo que se agregue: el archivo que se olvide falla por orden de
/// ejecución, que es la clase de falla más cara de encontrar. Acá se resuelve
/// una vez y para siempre.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(resetNeuronRegistry);

  await testMain();
}
