import 'package:flutter/foundation.dart';

/// Las claves que ya corrieron su revelado y todavia tienen dueno vivo.
///
/// **Es estado de libreria a proposito, y no un `InheritedWidget`.** El caso que
/// existe para resolver es el del `Hero`: cuando uno vuela, Flutter construye
/// una copia del hijo **en el overlay del `Navigator`**, que cuelga de otra rama
/// del arbol. Esa copia no ve ningun scope que este alrededor de la fila, asi
/// que la memoria tiene que ser alcanzable desde cualquier lado.
///
/// El precio es que hay que vaciarlo entre tests, y de eso se encarga el
/// `test/flutter_test_config.dart` de este package, que corre antes del `main`
/// de cada archivo. Un consumidor que monte estos widgets en sus propios tests
/// necesita el suyo.
///
/// **Una entrada puede sobrevivir a su dueno, y es el unico caso.** La copia que
/// el `Hero` arma en el overlay queda fuera de cualquier `NeuronRevealMemory`,
/// asi que si es *esa* la que marca y la fila real se desmonta antes de que el
/// vuelo termine, nadie olvida la clave. Se arregla solo la proxima vez que la
/// fila se monta y se va.
final _revealed = <String>{};

/// Separa al dueno de la parte dentro de una clave.
///
/// Las claves son `<dueno>$_partSeparator<parte>` porque [forgetNeuronRevealed]
/// borra por dueno y necesita reconocer sus partes sin llevar un mapa aparte.
const _partSeparator = '#';

/// Arma la clave de una parte de un elemento.
///
/// **Los dos lados van escapados, y no es decoracion.** Con el separador
/// literal, un dueno que lo contenga arma la misma cadena que otro par
/// distinto: `a#b` + `x` y `a` + `b#x` dan las dos `a#b#x`, o sea dos filas
/// compartiendo una entrada. Y peor, el prefijo `a#` de [forgetNeuronRevealed]
/// matchea la clave de `a#b`, asi que olvidar una fila se lleva la memoria de
/// otra.
///
/// En la app de la que salio esto no pasaba, porque sus identidades nunca
/// traian un `#`. Como package, quien lo use pasa lo que quiera.
String neuronRevealKey(String owner, String part) =>
    '${Uri.encodeComponent(owner)}$_partSeparator${Uri.encodeComponent(part)}';

/// Arma el dueno de una fila: la lista que la muestra, mas su identidad.
///
/// **El prefijo de lista no es decorativo.** La identidad de un juego es la
/// misma lo muestre quien lo muestre, y en esta app hay listas montadas a la vez
/// —`SearchPanel` es el `Drawer` del landing, asi que con el cajon abierto las
/// filas de deseados siguen montadas debajo—. Un juego que este en las dos
/// tendria un solo dueno: la fila de la busqueda lo veria ya revelado y
/// aparecereria resuelta sin revelar nada, y al cerrar el cajon su `dispose`
/// borraria la memoria de la fila de deseados, que nunca se fue del arbol.
String neuronRowOwner(String list, String identity) => '$list:$identity';

/// Si [key] ya se revelo y su dueno sigue montado.
bool neuronAlreadyRevealed(String key) => _revealed.contains(key);

/// Marca [key] como revelada.
///
/// Se llama **al arrancar** el revelado y no al terminarlo: mientras el `Hero`
/// vuela, la copia del overlay y la que queda en la lista se construyen casi a
/// la vez. Marcando al final, la segunda caeria en el hueco.
void markNeuronRevealed(String key) => _revealed.add(key);

/// Olvida todo lo que [owner] habia revelado.
///
/// **Esto es lo que hace que el scroll siga re-revelando.** La memoria dura lo
/// que dura la fila, no lo que dura la sesion: un `ListView.builder` destruye lo
/// que sale del viewport, y con la fila se va su entrada. Lo unico que remonta
/// un revelado **sin** destruir la fila es el vuelo de un `Hero`, y ese es
/// exactamente el rebote que hay que callar.
void forgetNeuronRevealed(String owner) {
  // Escapado igual que en [neuronRevealKey], o el prefijo no matchea sus
  // propias claves.
  final prefix = '${Uri.encodeComponent(owner)}$_partSeparator';

  _revealed.removeWhere((key) => key.startsWith(prefix));
}

/// Vacia el registro.
@visibleForTesting
void resetNeuronRegistry() => _revealed.clear();
