import SwiftUI

/// Sheet to schedule a pomodoro for later. At that time a notification asks to start or decline.
struct ScheduleComposer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
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

    init(initialPlan: SessionPlan) {
        _plan = State(initialValue: initialPlan)
        _date = State(initialValue: Self.suggestedDate())
    }

    var body: some View {
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

                    Text("\(DayLabel.short(for: date)) a las \(Formatting.time(date)) te llegará una notificación para empezar o rechazar.")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 240, alignment: .leading)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Programar") {
                    model.schedule(plan, at: date)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(date <= .now)
            }
        }
        .padding(28)
        .background(TomatoBackground())
        .foregroundStyle(Theme.cream)
        .tint(Theme.cream)
        .preferredColorScheme(.dark)
        .environment(\.locale, .app)
    }

    /// One hour from now, rounded up to the next five minutes (14:17 → 15:20).
    private static func suggestedDate() -> Date {
        let calendar = Calendar.current
        let inAnHour = Date.now.addingTimeInterval(3600)
        let wholeMinute = calendar.dateInterval(of: .minute, for: inAnHour)?.start ?? inAnHour
        let minute = calendar.component(.minute, from: wholeMinute)
        let roundUp = (5 - minute % 5) % 5
        return wholeMinute.addingTimeInterval(TimeInterval(roundUp * 60))
    }
}
