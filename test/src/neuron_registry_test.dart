import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  setUp(resetNeuronRegistry);

  group('neuronRegistry =>', () {
    test('una clave sin marcar no está revelada', () {
      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'cover')), isFalse);
    });

    test('marcar una clave la deja revelada', () {
      final clave = neuronRevealKey('123', 'cover');

      markNeuronRevealed(clave);

      expect(neuronAlreadyRevealed(clave), isTrue);
    });

    test('las partes de un mismo dueño son claves distintas', () {
      markNeuronRevealed(neuronRevealKey('123', 'cover'));

      // La portada y el bloque de texto de una fila corren su propio revelado
      // y resuelven en momentos distintos.
      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'info')), isFalse);
    });

    test('olvidar un dueño se lleva todas sus partes y sólo las suyas', () {
      markNeuronRevealed(neuronRevealKey('123', 'cover'));
      markNeuronRevealed(neuronRevealKey('123', 'info'));
      markNeuronRevealed(neuronRevealKey('456', 'cover'));

      forgetNeuronRevealed('123');

      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'cover')), isFalse);
      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'info')), isFalse);
      expect(neuronAlreadyRevealed(neuronRevealKey('456', 'cover')), isTrue);
    });

    test('olvidar un dueño no se lleva al que lo tiene como prefijo', () {
      markNeuronRevealed(neuronRevealKey('12', 'cover'));
      markNeuronRevealed(neuronRevealKey('123', 'cover'));

      // El separador es parte del prefijo que se borra: sin él, olvidar al
      // juego 12 se llevaría puesto al 123.
      forgetNeuronRevealed('12');

      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'cover')), isTrue);
    });

    test('el mismo juego en dos listas son dos dueños distintos', () {
      final enBusqueda = neuronRowOwner('search', 'igdb:123');
      final enDeseados = neuronRowOwner('wishlist', 'igdb:123');

      expect(enBusqueda, isNot(enDeseados));
    });

    test('cerrar una lista no borra la memoria de la otra', () {
      final enBusqueda = neuronRowOwner('search', 'igdb:123');
      final enDeseados = neuronRowOwner('wishlist', 'igdb:123');

      markNeuronRevealed(neuronRevealKey(enBusqueda, 'cover'));
      markNeuronRevealed(neuronRevealKey(enDeseados, 'cover'));

      // `SearchPanel` es el `Drawer` del landing: con el cajón abierto las filas
      // de deseados siguen montadas debajo. Sin el espacio de nombres, cerrar el
      // cajón se llevaba puesta la memoria de una fila que nunca se fue del
      // árbol, y el siguiente viaje al detalle desde deseados re-revelaba.
      forgetNeuronRevealed(enBusqueda);

      expect(
        neuronAlreadyRevealed(neuronRevealKey(enBusqueda, 'cover')),
        isFalse,
      );
      expect(
        neuronAlreadyRevealed(neuronRevealKey(enDeseados, 'cover')),
        isTrue,
      );
    });

    test('una fila no hereda el revelado de la otra lista', () {
      markNeuronRevealed(
        neuronRevealKey(neuronRowOwner('wishlist', 'igdb:123'), 'cover'),
      );

      // Si no, la fila de la búsqueda aparecía ya resuelta y sin revelar nada,
      // mientras las vecinas se revelaban.
      expect(
        neuronAlreadyRevealed(
          neuronRevealKey(neuronRowOwner('search', 'igdb:123'), 'cover'),
        ),
        isFalse,
      );
    });

    test('reset vacía el registro', () {
      markNeuronRevealed(neuronRevealKey('123', 'cover'));

      resetNeuronRegistry();

      expect(neuronAlreadyRevealed(neuronRevealKey('123', 'cover')), isFalse);
    });
  });
}
