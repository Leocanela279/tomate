import SwiftData
import SwiftUI

struct ScheduleScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \ScheduledPomodoro.fireDate) private var items: [ScheduledPomodoro]
    @State private var showingComposer = false
    /// Waiting for confirmation because starting it now would overlap something.
    @State private var pendingStart: PendingStart?

    /// A scheduled pomodoro the user wants to start now, and what that would overlap.
    private struct PendingStart: Identifiable {
        let item: ScheduledPomodoro
        let stopsRunning: Bool
        let collisions: [ScheduledPomodoro]
        var id: UUID { item.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Programados")
                    .font(Theme.font(30, .semibold))
                Spacer()
                if !items.isEmpty {
                    Button {
                        showingComposer = true
                    } label: {
                        Label("Programar", systemImage: "plus")
                    }
                    .buttonStyle(GlassButtonStyle())
                }
            }

            if items.isEmpty {
                EmptyState(title: "Nada programado",
                           message: "Elige día y hora y te avisaremos con una notificación para empezar o rechazar.") {
                    Button("Programar un pomodoro") { showingComposer = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                // Fire dates are whole minutes, so refreshing on each minute boundary
                // moves an item to "Esperando respuesta" exactly when it is due.
                TimelineView(.everyMinute) { context in
                    list(now: context.date)
                }
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, 24)
        .sheet(isPresented: $showingComposer) {
            ScheduleComposer(initialPlan: model.draft)
        }
        .confirmationDialog("¿Empezar ahora?", isPresented: isConfirmingStart, presenting: pendingStart) { pending in
            Button("Empezar") {
                model.start(pending.item, cancelling: pending.collisions)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { pending in
            Text(startMessage(pending))
        }
    }

    private func startMessage(_ pending: PendingStart) -> String {
        var parts: [String] = []
        if pending.stopsRunning {
            parts.append("El pomodoro en marcha se parará y se guardará en el historial con el tiempo que llevas.")
        }
        if !pending.collisions.isEmpty {
            parts.append(OverlapText.startingNow(pending.item.plan, collides: pending.collisions))
        }
        return parts.joined(separator: "\n\n")
    }

    private func list(now: Date) -> some View {
        let due = items.filter { $0.fireDate <= now }
        let upcoming = items.filter { $0.fireDate > now }

        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if !due.isEmpty {
                    section("Esperando respuesta") {
                        ForEach(due) { item in
                            DueRow(item: item,
                                   highlighted: item.id == model.highlightedScheduleID,
                                   onStart: { start(item) },
                                   onDismiss: { model.remove(item) })
                        }
                    }
                }
                if !upcoming.isEmpty {
                    section("Próximos") {
                        ForEach(upcoming) { item in
                            UpcomingRow(item: item,
                                        now: now,
                                        onStartNow: { start(item) },
                                        onCancel: { model.remove(item) })
                        }
                    }
                }
            }
            .padding(.bottom, 28)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.font(14, .semibold))
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    /// Starts right away unless that would stop the running pomodoro or overlap a later one;
    /// then the user confirms first.
    private func start(_ item: ScheduledPomodoro) {
        let collisions = Agenda.collisions(in: items, startingAt: .now,
                                           duration: TimeInterval(item.plan.totalSeconds),
                                           ignoring: item.id)
        if engine.isActive || !collisions.isEmpty {
            pendingStart = PendingStart(item: item, stopsRunning: engine.isActive, collisions: collisions)
        } else {
            model.start(item)
        }
    }

    private var isConfirmingStart: Binding<Bool> {
        Binding(get: { pendingStart != nil }, set: { if !$0 { pendingStart = nil } })
    }
}

// MARK: - Rows

private struct TimeBadge: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(DayLabel.short(for: date))
                .font(Theme.font(12, .medium))
                .foregroundStyle(Theme.secondaryText)
            Text(Formatting.time(date))
                .font(Theme.font(26, .medium))
                .monospacedDigit()
        }
        .frame(width: 84, alignment: .leading)
    }
}

/// Its time has come and nobody answered yet.
private struct DueRow: View {
    let item: ScheduledPomodoro
    let highlighted: Bool
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            TimeBadge(date: item.fireDate)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.plan.title)
                    .font(Theme.font(16, .semibold))
                    .lineLimit(1)
                Text(item.plan.summary)
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 12)
            Button("Rechazar", action: onDismiss)
                .buttonStyle(QuietButtonStyle())
            Button(action: onStart) {
                Label("Empezar", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .panel(cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.cream.opacity(highlighted ? 0.8 : 0), lineWidth: 1.5)
        }
    }
}

private struct UpcomingRow: View {
    let item: ScheduledPomodoro
    /// From the screen's TimelineView, so "dentro de 3 minutos" counts down.
    let now: Date
    let onStartNow: () -> Void
    let onCancel: () -> Void

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .app
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        HStack(spacing: 18) {
            TimeBadge(date: item.fireDate)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.plan.title)
                    .font(Theme.font(16, .semibold))
                    .lineLimit(1)
                Text(item.plan.summary)
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 12)
            // A plain String (not Text(date, format:)) so it redraws as `now` moves on.
            Text(Self.relative.localizedString(for: item.fireDate, relativeTo: now))
                .font(Theme.font(13))
                .foregroundStyle(Theme.secondaryText)
            Button(action: onCancel) {
                Image(systemName: "xmark")
            }
            .buttonStyle(GlassIconButtonStyle(size: 32))
            .help("Cancelar")
            .accessibilityLabel("Cancelar")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .panel(cornerRadius: 20)
        .contextMenu {
            Button("Empezar ahora", action: onStartNow)
            Button("Cancelar", role: .destructive, action: onCancel)
        }
    }
}
