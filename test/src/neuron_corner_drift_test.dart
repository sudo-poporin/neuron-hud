import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_hud/neuron_hud.dart';

void main() {
  /// Monta el reloj y va guardando las cuatro esquinas que publica.
  Widget montar({
    required List<List<Offset>> registro,
    double amplitude = neuronCornerDriftAmplitude,
    Duration period = const Duration(milliseconds: 1000),
    NeuronCornerDriftMode mode = NeuronCornerDriftMode.combined,
    int seed = 0,
    bool disableAnimations = false,
    bool tickerEnabled = true,
  }) {
    return MaterialApp(
      // El `MediaQuery` va adentro del `MaterialApp` y no afuera: el
      // `MaterialApp` arma el suyo desde la ventana y pisaría uno externo.
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: TickerMode(
          enabled: tickerEnabled,
          child: NeuronCornerDrift(
            amplitude: amplitude,
            period: period,
            mode: mode,
            seed: seed,
            builder: (context, corners) {
              registro.add(corners);
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      ),
    );
  }

  group('neuronCornerDriftPeriod =>', () {
    test('dos semillas distintas dan períodos distintos', () {
      expect(neuronCornerDriftPeriod(0), isNot(neuronCornerDriftPeriod(1)));
    });

    test('la misma semilla da siempre el mismo período', () {
      expect(neuronCornerDriftPeriod(5), neuronCornerDriftPeriod(5));
    });

    test('el período cae en el rango de la fórmula', () {
      for (var seed = 0; seed < 32; seed++) {
        final period = neuronCornerDriftPeriod(seed);

        expect(period.inMilliseconds, greaterThanOrEqualTo(2800));
        expect(period.inMilliseconds, lessThanOrEqualTo(4000));
      }
    });

    test('una semilla negativa sigue dando un período del rango', () {
      // El `%` de Dart sobre enteros devuelve siempre un valor no negativo.
      expect(
        neuronCornerDriftPeriod(-3).inMilliseconds,
        greaterThanOrEqualTo(2800),
      );
    });
  });

  group('NeuronCornerDrift =>', () {
    testWidgets('publica siempre cuatro esquinas', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();

      expect(registro.last, hasLength(4));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('las cuatro van desfasadas entre sí', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro));
      // Calentamiento: el primer tick del `Ticker` reporta `elapsed` cero.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      // Con la misma fase el marco entero se agranda y se achica al unísono,
      // que lee como un latido —una sola cosa— en vez de como cuatro marcas de
      // referencia buscando su lugar.
      expect(registro.last.toSet(), hasLength(4));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('en modo inset cada esquina entra hacia el centro', (
      tester,
    ) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(
        montar(registro: registro, mode: NeuronCornerDriftMode.inset),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final corners = registro.last;

      // La superior izquierda entra hacia la derecha y hacia abajo; la
      // inferior derecha, al revés. Nunca salen de la caja.
      expect(corners[0].dx, greaterThanOrEqualTo(0));
      expect(corners[0].dy, greaterThanOrEqualTo(0));
      expect(corners[3].dx, lessThanOrEqualTo(0));
      expect(corners[3].dy, lessThanOrEqualTo(0));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('en modo inset nunca se sale de la caja', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(
        montar(registro: registro, mode: NeuronCornerDriftMode.inset),
      );
      await tester.pump();

      // El seno va de cero a la amplitud, siempre hacia adentro: es lo que
      // separa a este modo del libre, donde una esquina sí puede salirse.
      for (var paso = 0; paso < 10; paso++) {
        await tester.pump(const Duration(milliseconds: 100));

        for (final corner in registro.last) {
          expect(
            corner.dx.abs(),
            lessThanOrEqualTo(neuronCornerDriftAmplitude),
          );
          expect(
            corner.dy.abs(),
            lessThanOrEqualTo(neuronCornerDriftAmplitude),
          );
        }
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('en modo free cada esquina recorre una elipse', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(
        montar(registro: registro, mode: NeuronCornerDriftMode.free),
      );
      await tester.pump();

      final alArrancar = registro.last.first;

      await tester.pump(const Duration(milliseconds: 250));

      final aUnCuarto = registro.last.first;

      // Los dos ejes desfasados un cuarto de vuelta entre sí: cuando uno está
      // en su máximo el otro pasa por cero, que es lo que la hace elipse y no
      // diagonal.
      expect(aUnCuarto.dx, isNot(closeTo(alArrancar.dx, 0.001)));
      expect(aUnCuarto.dy, isNot(closeTo(alArrancar.dy, 0.001)));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el modo combinado se corre más que cualquiera de los dos', (
      tester,
    ) async {
      final soloInset = <List<Offset>>[];
      final combinado = <List<Offset>>[];

      await tester.pumpWidget(
        montar(registro: soloInset, mode: NeuronCornerDriftMode.inset),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final recorridoInset = soloInset.last.first.distance;

      await tester.pumpWidget(const SizedBox());

      // El modo combinado es el default: lo que se compara es contra el
      // inset solo.
      await tester.pumpWidget(montar(registro: combinado));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Las dos componentes usan la misma amplitud, así que el desplazamiento
      // total llega al doble.
      expect(combinado.last.first.distance, greaterThan(recorridoInset));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('la semilla corre el desfase entre cajas vecinas', (
      tester,
    ) async {
      final conCero = <List<Offset>>[];
      final conUno = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: conCero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      await tester.pumpWidget(const SizedBox());

      await tester.pumpWidget(montar(registro: conUno, seed: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      // Dos cajas vecinas con el mismo período no tienen por qué moverse en
      // fase.
      expect(conUno.last, isNot(conCero.last));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con amplitud cero las cuatro quedan en cero', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro, amplitude: 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro.last, everyElement(Offset.zero));
    });

    testWidgets('con período cero tampoco: el controller ni arranca', (
      tester,
    ) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(
        montar(registro: registro, period: Duration.zero),
      );
      await tester.pump();

      expect(registro.last, everyElement(Offset.zero));
    });

    testWidgets('con «Reducir movimiento» el marco queda quieto', (
      tester,
    ) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(
        montar(registro: registro, disableAnimations: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro.last, everyElement(Offset.zero));
    });

    testWidgets('en una ruta inactiva no gasta: el TickerMode lo apaga', (
      tester,
    ) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro, tickerEnabled: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro.last, everyElement(Offset.zero));
    });

    testWidgets('prender el TickerMode en vivo lo arranca', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro, tickerEnabled: false));
      await tester.pump();

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(registro.last, isNot(everyElement(Offset.zero)));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar el período en vivo reprograma el controller', (
      tester,
    ) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();

      await tester.pumpWidget(
        montar(registro: registro, period: const Duration(milliseconds: 2000)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final aUnCuartoDelNuevo = registro.last;

      await tester.pumpWidget(const SizedBox());

      // La misma pose que un cuarto del período viejo, porque lo que manda es
      // la fracción del ciclo y no el tiempo absoluto.
      final referencia = <List<Offset>>[];
      await tester.pumpWidget(montar(registro: referencia));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      for (var i = 0; i < 4; i++) {
        expect(aUnCuartoDelNuevo[i].dx, closeTo(referencia.last[i].dx, 0.05));
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cambiar la amplitud en vivo la aplica', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final chico = registro.last.first.distance;

      await tester.pumpWidget(montar(registro: registro, amplitude: 20));
      await tester.pump();

      expect(registro.last.first.distance, greaterThan(chico));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un rebuild sin cambios no reprograma nada', (tester) async {
      final registro = <List<Offset>>[];

      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      final aMitadDeCamino = registro.last.first;

      // Mismo período y misma amplitud: el `didUpdateWidget` sale por el
      // `return` temprano y el controller sigue donde estaba.
      await tester.pumpWidget(montar(registro: registro));
      await tester.pump();

      expect(registro.last.first.dx, closeTo(aMitadDeCamino.dx, 0.2));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
