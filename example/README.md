# Ejemplo de `neuron_hud`

App de demostracion del package. Un tab por rol del sistema, cada efecto
**aislado y en bucle**: lo que se ve en cada pantalla es una sola cosa,
repitiendose, sin nada al lado que compita con ella.

```bash
flutter run
```

| Tab | Rol | Que corre |
| --- | --- | --- |
| Ausente | Contenido que todavia no resolvio | Las cuatro capas apiladas, movidas por relojes externos |
| Revelado | La entrada, que tiene principio y fin | `NeuronReveal`, con `slice` sobre una figura y sin `slice` sobre un texto |
| Ocupado | Algo esta pasando ahora | `NoiseSweep` sobre un icono y `TerminalCursor` al final de un texto |
| Stagger | El escalonado entre hermanos | `Stagger` sobre una lista, con los tres ordenes |

Las pantallas de **Revelado** y **Stagger** tienen un boton para volver a
correr la secuencia, porque termina: el bucle ahi es a pedido. Las de
**Ausente** y **Ocupado** no lo necesitan, porque no terminan nunca.

## Reducir movimiento

Con la opcion de accesibilidad prendida —`MediaQuery.disableAnimations`— todos
los efectos quedan estaticos, sin controller y sin timers. Se prueba desde los
ajustes de accesibilidad del sistema, sin tocar el codigo.
