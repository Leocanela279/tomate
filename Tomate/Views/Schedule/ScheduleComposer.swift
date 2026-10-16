import SwiftData
import SwiftUI

/// Sheet to schedule a pomodoro for later. At that time a notification asks to start or decline.
/// A time that would overlap another pomodoro can't be scheduled; the sheet offers the next free one.
struct ScheduleComposer: View {
    @Environment(AppModel.self) private var model
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @Query private var scheduled: [ScheduledPomodoro]
    @State private var plan: SessionPlan
    @State private var date: Date

    private struct QuickPick: Identifiable {
        let label: String
        let minutes: Int
        var id: Int { minutes }
    }

    private static let quickPicks = [
        QuickPick(label: "En 30 min", minutes: 30),
        QuickPick(label: "En 1 h", minutes: 60),
        QuickPick(label: "En 2 h", minutes: 120),
    ]

    private enum Status {
        case past
        case overlaps(Agenda.Slot, nextFree: Date)
        case free(start: Date, end: Date)
    }

    init(initialPlan: SessionPlan) {
        _plan = State(initialValue: initialPlan)
        _date = State(initialValue: Self.suggestedDate())
    }

    var body: some View {
        let status = currentStatus()

        VStack(alignment: .leading, spacing: 22) {
            Text("Programar pomodoro")
                .font(Theme.font(24, .semibold))

            HStack(alignment: .top, spacing: 28) {
                PlanEditor(plan: $plan)
                    .frame(width: 300)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Cuándo")
                        .font(Theme.font(14, .medium))
                        .foregroundStyle(Theme.secondaryText)

                    HStack(spacing: 6) {
                        ForEach(Self.quickPicks) { pick in
                            Button(pick.label) {
                                date = Date.now.addingTimeInterval(TimeInterval(pick.minutes * 60))
                            }
                            .buttonStyle(ChipButtonStyle())
                        }
                    }

                    DatePicker("Fecha y hora", selection: $date, in: Date.now...,
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()

                    statusView(status)
                }
                .frame(width: 240, alignment: .leading)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Programar") {
                    if model.schedule(plan, at: date) { dismiss() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!isFree(status))
            }
        }
        .padding(28)
        .background(TomatoBackground())
        .foregroundStyle(Theme.cream)
        .tint(Theme.cream)
        .preferredColorScheme(.dark)
        .environment(\.locale, .app)
        .onAppear {
            // Start from a time that is actually free.
            date = agenda.firstFreeStart(for: duration, from: date)
        }
    }

    // MARK: Status

    private var agenda: Agenda { Agenda(scheduled: scheduled, running: engine.session) }
    private var duration: TimeInterval { TimeInterval(plan.totalSeconds) }

    private func currentStatus() -> Status {
        let start = Agenda.floorToMinute(date)
        guard start > .now else { return .past }
        let interval = DateInterval(start: start, duration: duration)
        if let slot = agenda.conflict(with: interval) {
            return .overlaps(slot, nextFree: agenda.firstFreeStart(for: duration, from: start))
        }
        return .free(start: start, end: interval.end)
    }

    private func isFree(_ status: Status) -> Bool {
        if case .free = status { return true }
        return false
    }

    @ViewBuilder
    private func statusView(_ status: Status) -> some View {
        switch status {
        case .past:
            warning("Elige una hora a partir de ahora.")
        case .overlaps(let slot, let nextFree):
            VStack(alignment: .leading, spacing: 8) {
                warning(overlapMessage(slot))
                Button("Usar \(DayLabel.short(for: nextFree).lowercased()) a las \(Formatting.time(nextFree))") {
                    date = nextFree
                }
                .buttonStyle(ChipButtonStyle())
            }
        case .free(let start, let end):
            Text("\(DayLabel.short(for: start)) de \(Formatting.time(start)) a \(Formatting.time(end)). A las \(Formatting.time(start)) te llegará una notificación para empezar o rechazar.")
                .font(Theme.font(13))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func overlapMessage(_ slot: Agenda.Slot) -> String {
        let end = Formatting.time(slot.interval.end)
        if slot.id == nil {
            return "Se solapa con «\(slot.title)», que está en marcha hasta las \(end)."
        }
        return "Se solapa con «\(slot.title)», programado de \(Formatting.time(slot.interval.start)) a \(end)."
    }

    private func warning(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.font(13, .medium))
        .foregroundStyle(Theme.cream)
    }

    /// One hour from now, rounded up to the next five minutes (14:17 → 15:20).
    private static func suggestedDate() -> Date {
        let calendar = Calendar.current
        let inAnHour = Agenda.floorToMinute(Date.now.addingTimeInterval(3600))
        let minute = calendar.component(.minute, from: inAnHour)
        let roundUp = (5 - minute % 5) % 5
        return inAnHour.addingTimeInterval(TimeInterval(roundUp * 60))
    }
}
