# Tomate

Temporizador pomodoro para estudiar en macOS, hecho con SwiftUI. Pensado para sesiones largas: de **25 a 90 minutos**, no solo los 25 de siempre.

## Qué hace

- **Pomodoros de 25 a 90 min**, en pasos de 5 (con atajos de 25, 45, 60 y 90).
- **Dividir en dos bloques**: a partir de 60 min puedes meter un descanso de **15 o 20 min** a mitad, o hacerlo seguido.
- **Programar pomodoros** para más tarde. A la hora elegida llega una notificación de macOS con **Empezar** y **Rechazar**.
- **Sin solapes**: nunca hay dos pomodoros a la vez. No se puede programar uno que pise a otro (ni al que está en marcha); la app te propone el siguiente hueco libre. Si empiezas uno ahora que pisaría a uno programado, te pide confirmarlo y cancela el programado.
- **Barra de menú**: el tomate se queda arriba con el tiempo que falta. Si cierras la ventana, la app sigue ahí; haz clic para ver el tiempo, pausar, saltar o terminar.
- **Historial** con el tiempo estudiado hoy, los últimos 7 días (gráfica) y cada sesión.
- **Concentración automática** (opcional, en Ajustes ⌘,): activa tu modo Concentración durante los bloques de estudio y lo quita en los descansos, al pausar y al terminar. Ver más abajo.
- **Modo tomate y modo oscuro**: botón arriba a la derecha. El tema nuevo crece en círculo desde el botón mientras el resto de colores cambia con un fundido. La barra de menú sigue el mismo tema.
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

## Concentración automática

macOS no deja que una app active la Concentración por su cuenta, así que Tomate lo hace con dos atajos que creas una vez en la app Atajos:

1. **Tomate Estudiar**: acción de Concentración en *Activar*, con tu modo (No molestar o uno de estudio).
2. **Tomate Descansar**: la misma acción en *Desactivar*.
3. En *Ajustes del Sistema → Concentración → tu modo → Apps permitidas*, añade **Tomate**, para que sus avisos de descanso y de fin te lleguen igualmente.
4. En Tomate, abre Ajustes (⌘,), activa la opción y pulsa **Probar**. La primera vez macOS pide permiso para que Tomate use Atajos.

Tomate ejecuta *Tomate Estudiar* al empezar cada bloque de estudio y *Tomate Descansar* al empezar el descanso, al pausar y al terminar. Solo desactiva la Concentración si fue Tomate quien la activó.

## Publicar una versión

El botón de descarga de la web apunta siempre a `releases/latest/download/Tomate.dmg`, así que publicar es crear una etiqueta:

```sh
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions (`.github/workflows/release.yml`) compila Tomate en un Mac, crea `Tomate.dmg` con `scripts/make-dmg.sh` y lo adjunta a una Release con ese nombre. El mismo script funciona en local: `bash scripts/make-dmg.sh 1.0.0` deja el disco en `build/Tomate.dmg`.

El DMG va firmado "para ejecutar en local", sin certificado de desarrollador de Apple. Por eso, la primera vez macOS pide confirmación; la web explica los pasos. Para quitar ese aviso haría falta firmar con Developer ID y notarizar (Apple Developer Program).

## Web

La landing está en `landing/` (Astro + Tailwind CSS). Usa los mismos colores, el mismo botón de tema con el círculo que crece y la misma barra de pestañas que la app.

```sh
cd landing
npm install
npm run dev        # http://localhost:4321
```

Se publica en Cloudflare (Workers, archivos estáticos) en [usetomate.com](https://usetomate.com) cada vez que se sube `main`. En el proyecto de Cloudflare, *Settings → Build*:

| Campo | Valor |
| --- | --- |
| Root directory | `landing` |
| Build command | `npm run build` |
| Deploy command | `npx wrangler deploy` |

`landing/wrangler.jsonc` le dice a Cloudflare que sirva la carpeta `dist/` que genera Astro.

### Capturas con datos de ejemplo

Para hacer capturas sin enseñar tu historial, abre *Product → Scheme → Edit Scheme… → Run → Arguments* y activa `-TomateDemo`. Tomate arranca con un historial y unos programados de ejemplo en memoria; tus datos no se tocan, y en ese modo no programa recordatorios ni cambia la Concentración. Desactívalo al terminar.

## Atajos de teclado

| Atajo | Acción |
| --- | --- |
| ↩ | Empezar el pomodoro configurado |
| Espacio | Pausar / reanudar |
| ⌘1 · ⌘2 · ⌘3 | Temporizador · Programados · Historial |
| ⌘, | Ajustes (Concentración automática) |

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
├── Model/                   SessionPlan, ActiveSession, Agenda (regla de no solapes) y modelos SwiftData
├── Services/
│   ├── TimerEngine.swift    Cuenta atrás, fases, pausa, historial
│   ├── Notifier.swift       Avisos de fase y recordatorios programados
│   ├── FocusAutomation.swift Concentración automática con Atajos
│   └── Persistence.swift    Contenedor SwiftData y aviso si no se puede guardar
├── Design/                  Paletas (tomate y oscuro), cambio de tema, botones, el dial-tomate
├── Views/                   Temporizador, Programados, Historial, barra de menú, Ajustes
└── Support/                 Formatos en español y datos de ejemplo (-TomateDemo)
landing/                     Web en Astro + Tailwind CSS
scripts/make-dmg.sh          Compila en Release y crea build/Tomate.dmg
.github/workflows/           Release con el DMG
```

Algunas decisiones:

- **El temporizador no cuenta segundos, compara fechas.** `ActiveSession` guarda cuándo termina la fase actual; cada tic solo calcula cuánto falta. Por eso no se desfasa con el reposo del Mac ni con App Nap, y la sesión se recupera si cierras la app.
- **Los avisos de fase se programan al empezar.** Si la app está cerrada o el Mac dormido, la notificación llega igualmente a su hora.
- **Solo el dial se redibuja cada segundo.** El resto de la pantalla depende de `session`, que cambia únicamente al pausar o cambiar de fase.
- **Las sesiones de menos de 1 minuto terminadas a mano no se guardan** en el historial, para no llenarlo de pruebas.
- **Si no se puede guardar** (por ejemplo, con el disco lleno), los cambios se deshacen y la app lo avisa en un banner, en vez de fallar en silencio.
