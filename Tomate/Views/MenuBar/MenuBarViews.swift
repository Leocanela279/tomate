import AppKit
import SwiftData
import SwiftUI

/// What sits in the menu bar: the tomato alone, or an icon plus the time left.
struct MenuBarLabel: View {
    let engine: TimerEngine

    var body: some View {
        if let session = engine.session {
            HStack(spacing: 4) {
                icon(for: session)
                Text(Formatting.clock(engine.remaining))
                    .monospacedDigit()
            }
        } else {
            Image("MenuBarTomato")
        }
    }

    @ViewBuilder
    private func icon(for session: ActiveSession) -> some View {
        if session.isPaused {
            Image(systemName: "pause.fill")
        } else if session.currentPhase.kind == .rest {
            Image(systemName: "leaf.fill")
        } else {
            Image("MenuBarTomato")
        }
    }
}

/// The small window that opens from the menu bar.
struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(TimerEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ScheduledPomodoro.fireDate) private var scheduled: [ScheduledPomodoro]
    /// Follows the theme chosen in the main window.
    @AppStorage(ThemeMode.storageKey) private var mode: ThemeMode = .tomato

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session = engine.session {
                ActiveSection(session: session)
            } else {
                idleSection
            }

            Rectangle()
                .fill(Theme.text.opacity(0.14))
                .frame(height: 1)

            HStack {
                Button("Abrir Tomate") { model.presentMainWindow() }
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(QuietButtonStyle())
            .padding(.horizontal, -10)
        }
        .padding(18)
        .frame(width: 300)
        .background(TomatoBackground())
        .foregroundStyle(Theme.text)
        .tint(mode.palette.accentFill)
        .environment(\.palette, mode.palette)
        .preferredColorScheme(.dark)
        .environment(\.locale, .app)
        .onAppear {
            model.openMainWindow = { openWindow(id: AppModel.mainWindowID) }
        }
    }

    private var idleSection: some View {
        // The panel has no room for a confirmation: if starting now would overlap
        // a scheduled pomodoro, the button opens Tomate, where the user decides.
        let collisions = Agenda.collisions(in: scheduled, startingAt: .now,
                                           duration: TimeInterval(model.draft.totalSeconds))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TomatoDial(fraction: 1, kind: .focus, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tomate")
                        .font(Theme.font(17, .semibold))
                    Text("Sin pomodoro en marcha")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Button {
                if collisions.isEmpty {
                    model.startDraft()
                } else {
                    model.selectedTab = .timer
                    model.presentMainWindow()
                }
            } label: {
                Label("Empezar \(model.draft.focusMinutes) min", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))

            if let first = collisions.first {
                Text("Se solaparía con «\(first.plan.title)» a las \(Formatting.time(first.fireDate)). Ábrelo en Tomate para decidir.")
                    .font(Theme.font(12, .medium))
                    .fixedSize(horizontal: false, vertical: true)
            } else if let next = scheduled.first(where: { $0.fireDate > .now }) {
                Text("Siguiente: \(DayLabel.short(for: next.fireDate).lowercased()) a las \(Formatting.time(next.fireDate)), \(next.plan.title)")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Live part of the panel; only this redraws every second while the panel is open.
private struct ActiveSection: View {
    @Environment(TimerEngine.self) private var engine
    let session: ActiveSession

    var body: some View {
        let kind = session.currentPhase.kind

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                TomatoDial(fraction: engine.remainingFraction, kind: kind, size: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatting.clock(engine.remaining))
                        .font(Theme.font(36, .light))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text(session.isPaused ? "En pausa" : kind.title)
                        .font(Theme.font(13, .semibold))
                        .foregroundStyle(Theme.phase(kind))
                    Text(session.plan.title)
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Button {
                    engine.togglePause()
                } label: {
                    Label(session.isPaused ? "Reanudar" : "Pausar",
                          systemImage: session.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))

                if !session.isLastPhase {
                    Button {
                        engine.skipPhase()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .buttonStyle(GlassIconButtonStyle(size: 40))
                    .help(kind == .rest ? "Saltar el descanso" : "Pasar al descanso")
                }

                Button {
                    engine.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(GlassIconButtonStyle(size: 40))
                .help("Terminar y guardar en el historial")
            }

            if !session.isPaused {
                Text("Termina a las \(Formatting.time(session.expectedEnd(from: .now)))")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
