# ScrollFlip

App para macOS que hace dos cosas:

- **Invierte el desplazamiento**, con una dirección para el trackpad y otra para el ratón (Natural, Clásico o Sin cambios), y opción de invertir también el horizontal.
- **Cierra la app entera al pulsar el botón rojo** de una ventana, como si pulsaras ⌘Q. Mantén ⌥ Option al hacer clic para cerrar solo la ventana. El Finder nunca se cierra.

No aparece en la barra de menús: para abrir los ajustes, vuelve a abrir ScrollFlip desde el Finder o Spotlight.

Necesita el permiso de **Accesibilidad** (Ajustes del Sistema → Privacidad y seguridad → Accesibilidad).

## Compilar

Hace falta Xcode (para el compilador de Swift y para compilar el icono de Icon Composer):

```
./build.sh
```

Genera `ScrollFlip.app` junto al script, firmada ad hoc.

## Créditos

El desplazamiento y la interfaz se basan en [Scroll Reverser](https://github.com/pilotmoon/Scroll-Reverser), de Nick Moore, con licencia Apache 2.0. Ver `NOTICE` y `LICENSE`.
