import 'package:flutter/widgets.dart';

/// Blanco pleno de las capas: los corchetes del marco y las barras de ruido.
///
/// No es un color de marca y no sale del `ColorScheme` de nadie: esta carpeta
/// esta pensada para salir a un package propio, y un package no puede leer el
/// tema de su consumidor. Quien la use pasa el color que quiera.
const astralInk = Color(0xFFFFFFFF);

/// Blanco atenuado, para el andamio que no debe competir con el contenido.
const astralInkDim = Color(0x66FFFFFF);

/// Blanco apenas visible, para textura de fondo.
const astralInkFaint = Color(0x33FFFFFF);

/// Cian de la capa izquierda de la aberracion cromatica.
///
/// Sale del frame del pico de `logo_animation.mp4`, el video del blog oficial
/// de PlatinumGames en https://www.platinumgames.com/official-blog/article/10397.
/// Es un default, no una imposicion: el color entra por parametro.
const astralChromaticA = Color(0xFF00FFFF);

/// Rojo de la capa derecha de la aberracion cromatica.
///
/// El par con [astralChromaticA] sale del mismo frame.
const astralChromaticB = Color(0xFFFF0055);
