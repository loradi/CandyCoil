# Candy Coil

Prototipo nativo para iPhone/iPad (iOS 17+), escrito en SwiftUI y SpriteKit. El motor de juego funciona localmente; el inicio de sesión social y las salas usan Supabase.

Sitio del proyecto (inglés, español y francés): [Inicio](docs/index.html) · [Privacidad](docs/privacy.html) · [Términos](docs/terms.html).

## Abrir y jugar

1. Abre `CandyCoil.xcodeproj` con Xcode.
2. Selecciona el esquema CandyCoil y un simulador de iPhone. Pulsa Run (⌘R).
3. Para instalar en un iPhone físico, conecta el dispositivo y configura tu equipo en Signing & Capabilities. La firma no está configurada en este repositorio.

Joystick en pantalla, stick izquierdo o cruceta de un mando compatible con GameController previamente emparejado en Ajustes de iOS. El mando controla la dirección; los menús usan controles táctiles. Se pausa al salir de la app.

## Primera versión

- Arena de 12.000 × 12.000 con cámara, radar y 24 rivales IA.
- Movimiento libre; cruzar el propio cuerpo está permitido.
- La cabeza contra un rival o el límite causa eliminación. Dos cabezas que chocan se eliminan simultáneamente.
- 50 variantes: 10 familias de dulces con 5 tamaños, crecimiento y rareza distintos. El 7,5% de los dulces son radiantes, brillan en la arena y dan 3× crecimiento. Se usan emojis provisionales para las ilustraciones.
- Todos los dulces consumidos se depositan sobre el cuerpo al morir. Reintentar conserva la arena y el botín; volver al inicio y empezar crea otra arena.
- Récord, colección, idioma y apariencia guardados localmente. Inglés como idioma inicial, con español y francés. Colores y caras de Coil configurables. Pausa, resultados y reinicio.
- Protección de 2 segundos al aparecer frente a rivales; los bordes siguen siendo peligrosos.

## Estructura y comprobaciones

`CandyCoil/Core` contiene la simulación independiente de la interfaz. `CandyCoil/App` contiene pantallas, renderizado y controles. `project.yml` permite regenerar el proyecto con `xcodegen generate`.

```sh
swift test
xcodebuild -project CandyCoil.xcodeproj -scheme CandyCoil -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Pendiente para una versión comercial: multijugador real con servidor autoritativo, arte propio, audio, icono de app, ajuste de rendimiento en dispositivo físico y distribución por TestFlight/App Store. El soporte de mando requiere verificación con hardware real.

## Cuenta y partidas online

El acceso Google está configurado a través del proyecto Supabase CandyCoil y un cliente OAuth web propio del proyecto Google Cloud `CandyCoil Auth`; no reutiliza las credenciales de Megachimbita. Supabase usa `candycoil://auth-callback` como URL de retorno y mantiene las credenciales secretas en el servidor. Google OAuth está en modo de prueba: por ahora solo las cuentas añadidas a la lista de testers pueden iniciar sesión. La partida y las salas siguen siendo locales con bots; configurar OAuth no activa por sí solo el multijugador en tiempo real.

## Validación de esta entrega

Compilación para iOS Simulator correcta y seis pruebas del motor aprobadas: catálogo, crecimiento, cruce propio, colisiones/botín/reaparición, límites y simulación de diez segundos. Captura real del lobby en `Screenshots/lobby.png`.

Prueba de interfaz aprobada en iPhone 18 Pro (iOS Simulator 27.0): abrir el lobby, iniciar partida, pausar, continuar y volver al inicio. Total: 6 pruebas del motor + 1 prueba de interfaz, sin fallos. Bluetooth e instalación en iPhone físico aún no verificados.
