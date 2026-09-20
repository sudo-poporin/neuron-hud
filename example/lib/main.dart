import 'package:example/absent_screen.dart';
import 'package:example/busy_screen.dart';
import 'package:example/reveal_screen.dart';
import 'package:example/stagger_screen.dart';
import 'package:flutter/material.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() => runApp(const ExampleApp());

/// La app de ejemplo de `neuron_hud`: un tab por rol del sistema.
class ExampleApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'neuron_hud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          surface: _background,
          primary: astralChromaticA,
        ),
      ),
      home: const _Home(),
    );
  }
}

/// El fondo oscuro de la app.
///
/// El package trae sus colores en blanco —`astralInk` y sus dos atenuaciones—
/// porque son los de la referencia y porque **no puede leer el tema de su
/// consumidor**. Sobre un fondo claro habría que pasarle otra tinta por
/// parámetro a cada capa.
const _background = Color(0xFF101014);

class _Home extends StatefulWidget {
  const new();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _background,
        title: Text(
          tab.title,
          style: const TextStyle(letterSpacing: 2, fontSize: 15),
        ),
      ),
      // Solo se construye el tab visible, y no un `IndexedStack`: los efectos
      // de los otros tres tienen reloj propio, así que mantenerlos montados
      // dejaría timers corriendo detrás de lo que se está mirando. Aislado
      // quiere decir aislado.
      body: SafeArea(child: SingleChildScrollView(child: tab.screen)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: _background,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.title),
        ],
      ),
    );
  }
}

/// Un tab: su nombre, su ícono y la pantalla que muestra.
///
/// Las cuatro pantallas se instancian acá, pero instanciar un widget no lo
/// monta: es una descripción. La que entra al árbol es la del tab elegido.
typedef _Tab = ({String title, IconData icon, Widget screen});

const _tabs = <_Tab>[
  (title: 'AUSENTE', icon: Icons.crop_square, screen: AbsentScreen()),
  (title: 'REVELADO', icon: Icons.auto_awesome, screen: RevealScreen()),
  (title: 'OCUPADO', icon: Icons.sync, screen: BusyScreen()),
  (title: 'STAGGER', icon: Icons.view_list, screen: StaggerScreen()),
];
