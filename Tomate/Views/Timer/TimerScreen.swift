import SwiftData
import SwiftUI

struct TimerScreen: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        HStack(spacing: 40) {
            LiveDial()
                .frame(maxWidth: .infinity)

            Group {
                if let session = engine.session {
                    SessionPanel(session: session)
                } else {
                    PlanPanel()
                }
            }
            .frame(width: 360)
            .transition(.opacity)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 28)
        .animation(.smooth(duration: 0.35), value: engine.isActive)
    }
}

/// The big tomato. It is the only part of the screen that redraws every second.
private struct LiveDial: View {
    @Environment(AppModel.self) private var model
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let session = engine.session {
            let kind = session.currentPhase.kind
            dial(fraction: engine.remainingFraction,
                 time: Formatting.clock(engine.remaining),
                 caption: session.isPaused ? "En pausa" : kind.title,
                 detail: session.detailLine,
                 kind: kind)
        } else {
            let plan = model.draft
            dial(fraction: 1,
                 time: Formatting.clock(plan.phases.first?.seconds ?? 0),
                 caption: PhaseKind.focus.title,
                 detail: plan.isSplit ? "Bloque 1 de 2" : "Listo para empezar",
                 kind: .focus)
        }
    }

    private func dial(fraction: Double, time: String, caption: String, detail: String?, kind: PhaseKind) -> some View {
        TomatoDial(fraction: fraction, kind: kind, size: 300) {
            VStack(spacing: 6) {
                Text(time)
                    .font(Theme.font(70, .light))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .snappy, value: time)
                Text(caption)
                    .font(Theme.font(17, .semibold))
                    .foregroundStyle(Theme.accent(for: kind))
                if let detail {
                    Text(detail)
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.top, 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption). Quedan \(time).")
    }
}

extension ActiveSession {
    /// Where the user is inside a split session; nothing for a single block.
    var detailLine: String? {
        guard blockCount > 1 else { return nil }
        if currentPhase.kind == .rest { return "Antes del bloque 2" }
        return "Bloque \(blockNumber) de \(blockCount)"
    }
}

// MARK: - Before starting

private struct PlanPanel: View {
    @Environment(AppModel.self) private var model
    @Query private var scheduled: [ScheduledPomodoro]
    @State private var showingScheduler = false
    /// Scheduled pomodoros that starting now would overlap, waiting for the user's decision.
    @State private var collisions: [ScheduledPomodoro] = []

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 18) {
            PlanEditor(plan: $model.draft)

            VStack(spacing: 6) {
                Button {
                    let found = Agenda.collisions(in: scheduled, startingAt: .now,
                                                  duration: TimeInterval(model.draft.totalSeconds))
                    if found.isEmpty {
                        model.startDraft()
                    } else {
                        collisions = found
                    }
                } label: {
                    Label("Empezar", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                .keyboardShortcut(.defaultAction)

                Button("Programar para más tarde") {
                    showingScheduler = true
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(24)
        .panel()
        .onChange(of: model.draft) { _, plan in
            plan.saveAsDraft()
        }
        .sheet(isPresented: $showingScheduler) {
            ScheduleComposer(initialPlan: model.draft)
        }
        .confirmationDialog("Se solapa con un pomodoro programado", isPresented: hasCollisions) {
            Button(startAnywayTitle) {
                model.startDraft(cancelling: collisions)
                collisions = []
            }
            Button("Cancelar", role: .cancel) { collisions = [] }
        } message: {
            Text(OverlapText.startingNow(model.draft, collides: collisions))
        }
    }

    private var hasCollisions: Binding<Bool> {
        Binding(get: { !collisions.isEmpty }, set: { if !$0 { collisions = [] } })
    }

    private var startAnywayTitle: String {
        collisions.count == 1 ? "Empezar y cancelar el programado" : "Empezar y cancelar los programados"
    }
}

// MARK: - While running

private struct SessionPanel: View {
    @Environment(TimerEngine.self) private var engine
    let session: ActiveSession
    @State private var confirmingStop = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.plan.title)
                    .font(Theme.font(26, .semibold))
                    .lineLimit(2)
                Text(statusLine)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.secondaryText)
            }

            if session.phases.count > 1 {
                PhaseTimeline(session: session)
            } else {
                Text(session.plan.summary)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.secondaryText)
            }

            controls
                .padding(.top, 6)
        }
        .padding(24)
        .panel()
    }

    private var statusLine: String {
        if session.isPaused { return "En pausa. El tiempo no corre." }
        return "Termina a las \(Formatting.time(session.expectedEnd(from: .now)))"
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                engine.togglePause()
            } label: {
                Label(session.isPaused ? "Reanudar" : "Pausar",
                      systemImage: session.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .keyboardShortcut(.space, modifiers: [])

            if !session.isLastPhase {
                Button {
                    engine.skipPhase()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(GlassIconButtonStyle())
                .help(session.currentPhase.kind == .rest ? "Saltar el descanso" : "Pasar al descanso")
                .accessibilityLabel(session.currentPhase.kind == .rest ? "Saltar el descanso" : "Pasar al descanso")
            }

            Button {
                confirmingStop = true
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(GlassIconButtonStyle())
            .help("Terminar")
            .accessibilityLabel("Terminar")
            .confirmationDialog("¿Terminar este pomodoro?", isPresented: $confirmingStop) {
                Button("Terminar", role: .destructive) { engine.stop() }
                Button("Seguir estudiando", role: .cancel) {}
            } message: {
                Text("El tiempo que llevas se guardará en el historial.")
            }
        }
    }
}

/// The phases of a split session as a vertical sequence: done, current, next.
private struct PhaseTimeline: View {
    let session: ActiveSession

    private enum Step { case done, current, upcoming }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(session.phases) { phase in
                let step = stepFor(phase)
                HStack(spacing: 14) {
                    marker(kind: phase.kind, step: step)
                    Text(phase.kind.title)
                        .font(Theme.font(15, step == .current ? .semibold : .regular))
                    Spacer()
                    Text(Formatting.minutes(fromSeconds: phase.seconds))
                        .font(Theme.font(14))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                }
                .foregroundStyle(step == .upcoming ? Theme.secondaryText : Theme.cream)
                .frame(height: 40)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func stepFor(_ phase: Phase) -> Step {
        if phase.id < session.phaseIndex { return .done }
        if phase.id == session.phaseIndex { return .current }
        return .upcoming
    }

    @ViewBuilder
    private func marker(kind: PhaseKind, step: Step) -> some View {
        let color = Theme.accent(for: kind)
        ZStack {
            switch step {
            case .done:
                Circle().fill(color.opacity(0.9))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.tomatoDeep)
            case .current:
                Circle().stroke(color.opacity(0.35), lineWidth: 4)
                Circle().fill(color).padding(4)
            case .upcoming:
                Circle().stroke(Theme.cream.opacity(0.4), lineWidth: 1.5)
            }
        }
        .frame(width: 18, height: 18)
    }
}
