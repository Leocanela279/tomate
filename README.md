# Tomate

Temporizador pomodoro para estudiar en macOS, hecho con SwiftUI. Pensado para sesiones largas: de **25 a 90 minutos**, no solo los 25 de siempre.

## Qué hace

- **Pomodoros de 25 a 90 min**, en pasos de 5 (con atajos de 25, 45, 60 y 90).
- **Dividir en dos bloques**: a partir de 60 min puedes meter un descanso de **15 o 20 min** a mitad, o hacerlo seguido.
- **Programar pomodoros** para más tarde. A la hora elegida llega una notificación de macOS con **Empezar** y **Rechazar**.
- **Barra de menú**: el tomate se queda arriba con el tiempo que falta. Si cierras la ventana, la app sigue ahí; haz clic para ver el tiempo, pausar, saltar o terminar.
- **Historial** con el tiempo estudiado hoy, los últimos 7 días (gráfica) y cada sesión.
- Pausar, reanudar (barra espaciadora), saltar al descanso y terminar.
- El tiempo se guarda como fechas, así que sigue siendo exacto si el Mac se duerme o si cierras y vuelves a abrir la app.

Todo es local: sin cuentas, sin servidor y sin base de datos externa.

## Requisitos

- macOS 14 Sonoma o posterior.
- Xcode 16 o posterior. Con **Xcode 26 y macOS 26** los controles usan Liquid Glass; en versiones anteriores, un material translúcido.

## Cómo ejecutarlo

1. Abre `Tomate.xcodeproj`.
2. Elige el esquema **Tomate** y pulsa ⌘R.
3. La primera vez, acepta las notificaciones.

El proyecto firma con "Sign to Run Locally", así que no necesitas cuenta de desarrollador para probarlo. Si quieres firmarlo con tu equipo, cámbialo en *Signing & Capabilities*.

> **Consejo:** en *Ajustes del Sistema → Notificaciones → Tomate*, pon el estilo en **Alertas**. Así el aviso de un pomodoro programado se queda en pantalla con los botones Empezar / Rechazar hasta que respondas.

## Atajos

| Atajo | Acción |
| --- | --- |
| ↩ | Empezar el pomodoro configurado |
| Espacio | Pausar / reanudar |
| ⌘1 · ⌘2 · ⌘3 | Temporizador · Programados · Historial |

## Cómo está hecho

| Parte | Herramienta de Apple |
| --- | --- |
| Interfaz y estado | SwiftUI + Observation (`@Observable`) |
| Historial y programados | SwiftData |
| Sesión en curso y último plan | `UserDefaults` (JSON con `Codable`) |
| Avisos | UserNotifications |
| Gráfica | Swift Charts |
| Barra de menú | `MenuBarExtra` |

```
Tomate/
├── TomateApp.swift          Escenas: ventana principal y barra de menú
├── AppDelegate.swift        Ciclo de vida y respuestas a notificaciones
├── AppModel.swift           Une almacenamiento, temporizador y notificaciones
├── Model/                   SessionPlan, ActiveSession y modelos SwiftData
├── Services/
│   ├── TimerEngine.swift    Cuenta atrás, fases, pausa, historial
│   ├── Notifier.swift       Avisos de fase y recordatorios programados
│   └── Persistence.swift    Contenedor SwiftData y aviso si no se puede guardar
├── Design/                  Paleta, botones, el dial-tomate
├── Views/                   Temporizador, Programados, Historial, barra de menú
└── Support/Formatting.swift Formatos de hora y duración en español
```

Algunas decisiones:

- **El temporizador no cuenta segundos, compara fechas.** `ActiveSession` guarda cuándo termina la fase actual; cada tic solo calcula cuánto falta. Por eso no se desfasa con el reposo del Mac ni con App Nap, y la sesión se recupera si cierras la app.
- **Los avisos de fase se programan al empezar.** Si la app está cerrada o el Mac dormido, la notificación llega igualmente a su hora.
- **Solo el dial se redibuja cada segundo.** El resto de la pantalla depende de `session`, que cambia únicamente al pausar o cambiar de fase.
- **Las sesiones de menos de 1 minuto terminadas a mano no se guardan** en el historial, para no llenarlo de pruebas.
- **Si no se puede guardar** (por ejemplo, con el disco lleno), los cambios se deshacen y la app lo avisa en un banner, en vez de fallar en silencio.
