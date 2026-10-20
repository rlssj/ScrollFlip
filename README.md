# ScrollFlip

App para macOS que hace dos cosas:

- **Cambia el desplazamiento**: eliges una dirección para el trackpad y otra para el ratón (Natural, Clásico o Sin cambios), y si quieres, también la del desplazamiento horizontal.
- **Cierra la app entera con el botón rojo** de una ventana, como si pulsaras ⌘Q. Mantén ⌥ al hacer clic para cerrar solo la ventana. El Finder nunca se cierra.

## Instalar

1. Descarga **ScrollFlip.zip** de la [última versión](../../releases/latest) y descomprímelo.
2. Mueve **ScrollFlip** a Aplicaciones.
3. La primera vez, haz **clic derecho → Abrir** (no está firmada por Apple, así que macOS avisa). Si no te deja, ve a Ajustes del Sistema → Privacidad y seguridad y pulsa **Abrir igualmente**.
4. Dale el permiso de **Accesibilidad** cuando lo pida.

No ocupa sitio en la barra de menús ni en el Dock: para ver los ajustes, vuelve a abrir ScrollFlip.

## Cómo se compila

GitHub la compila sola en cada cambio (`.github/workflows/compilar.yml`) con `build.sh`, que necesita Xcode para el compilador de Swift y para el icono de Icon Composer. Cada compilación guarda también capturas de la ventana de ajustes.

## Créditos

El desplazamiento se basa en [Scroll Reverser](https://github.com/pilotmoon/Scroll-Reverser), de Nick Moore, con licencia Apache 2.0. Ver `NOTICE` y `LICENSE`.
