# ScrollFlip

App para macOS que hace dos cosas:

- **Cambia el desplazamiento**: eliges una dirección para el trackpad y otra para el ratón (Natural, Clásico o Sin cambios), y si quieres, también la del desplazamiento horizontal.
- **Cierra la app entera con el botón rojo** cuando cierras su última ventana, como si pulsaras ⌘Q. Si tiene más ventanas abiertas, solo se cierra esa. En las apps que añadas como excepción (o si mantienes ⌥ al hacer clic) solo se cierra la ventana. El Finder nunca se cierra.

## Instalar

1. Descarga **ScrollFlip.zip** de la [última versión](../../releases/latest) y descomprímelo.
2. Mueve **ScrollFlip** a Aplicaciones.
3. Ábrela. Como no está firmada por Apple, macOS dirá que no puede comprobarla: ve a Ajustes del Sistema → Privacidad y seguridad y, abajo del todo, pulsa **Abrir igualmente**. Solo hace falta la primera vez.
4. Dale el permiso de **Accesibilidad** cuando lo pida.

No ocupa sitio en la barra de menús ni en el Dock: para ver los ajustes, vuelve a abrir ScrollFlip.

## Cómo se compila

GitHub la compila sola en cada cambio (`.github/workflows/compilar.yml`) con `build.sh`, que necesita Xcode para el compilador de Swift y para el icono de Icon Composer. Cada compilación guarda también capturas de la ventana de ajustes.

## Créditos

El desplazamiento se basa en [Scroll Reverser](https://github.com/pilotmoon/Scroll-Reverser), de Nick Moore, con licencia Apache 2.0. Ver `NOTICE` y `LICENSE`.
