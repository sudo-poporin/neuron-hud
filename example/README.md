# Ejemplo de `neuron_hud`

App de demostracion del package. Un tab por rol del sistema mas dos por las
familias que no son un rol, cada efecto **aislado y en bucle**: lo que se ve en
cada pantalla es una sola cosa, repitiendose, sin nada al lado que compita con
ella.

```bash
flutter run
```

| Tab | Rol | Que corre |
| --- | --- | --- |
| Ausente | Contenido que todavia no resolvio | Las cuatro capas apiladas, movidas por relojes externos |
| Revelado | La entrada, que tiene principio y fin | `NeuronReveal`, con `slice` sobre una figura y sin `slice` sobre un texto |
| Ocupado | Algo esta pasando ahora | `NoiseSweep` en sus dos modos, `TerminalCursor`, `ChromaticBurst` y `SlicedBox` |
| Stagger | El escalonado entre hermanos | `Stagger` sobre una lista, con los tres ordenes |
| Desfase | El modificador | `Perspective`, que corre las partes de un elemento unas respecto de otras |

Las pantallas de **Revelado** y **Stagger** repiten solas, porque su secuencia
termina: el boton no habilita la repeticion, adelanta la corrida siguiente y
reinicia el reloj. Las de **Ausente** y **Ocupado** no tienen boton porque no
terminan nunca.

**Desfase** es la excepcion: `Perspective` es la unica de las cinco familias sin
reloj propio y sin `progress`. No corre ni en bucle ni una vez —modifica como se
apila un elemento y se queda asi—, asi que es la unica pantalla que se ve igual
en una captura fija que en vivo.

## Reducir movimiento

Con la opcion de accesibilidad prendida —`MediaQuery.disableAnimations`— todos
los efectos quedan estaticos, sin controller y sin timers. Se prueba desde los
ajustes de accesibilidad del sistema, sin tocar el codigo.
