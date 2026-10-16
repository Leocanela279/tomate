import SwiftUI

/// Subject, length and the optional break in the middle. Used to start now and to schedule.
struct PlanEditor: View {
    @Binding var plan: SessionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("Tema", text: $plan.subject, prompt: Text("¿Qué vas a estudiar?"))
                .textFieldStyle(.plain)
                .font(Theme.font(16, .medium))
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(Theme.wine.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Duración")
                        .font(Theme.font(14, .medium))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(plan.focusMinutes) min")
                        .font(Theme.font(22, .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: plan.focusMinutes)
                }

                ChoiceControl(selection: $plan.focusMinutes,
                              options: SessionPlan.presets.map { Choice(value: $0, label: "\($0)") })

                Slider(value: minutes,
                       in: Double(SessionPlan.minuteRange.lowerBound)...Double(SessionPlan.minuteRange.upperBound),
                       step: Double(SessionPlan.minuteStep))
                    .controlSize(.small)
                    .accessibilityLabel("Duración en minutos")
            }

            if plan.canSplit {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Descanso a mitad")
                        .font(Theme.font(14, .medium))
                        .foregroundStyle(Theme.secondaryText)
                    ChoiceControl(selection: breakChoice, options: Self.breakOptions)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            PlanBar(plan: plan)
        }
        .animation(.smooth(duration: 0.3), value: plan.canSplit)
    }

    private static let breakOptions: [Choice<Int>] =
        [Choice(value: 0, label: "Sin descanso")]
        + SessionPlan.breakChoices.map { Choice(value: $0, label: "\($0) min") }

    private var minutes: Binding<Double> {
        Binding(
            get: { Double(plan.focusMinutes) },
            set: { plan.focusMinutes = Int($0.rounded()) }
        )
    }

    /// 0 means "do it in one go"; otherwise the length of the break in the middle.
    private var breakChoice: Binding<Int> {
        Binding(
            get: { plan.isSplit ? plan.breakMinutes : 0 },
            set: { value in
                plan.splitEnabled = value > 0
                if value > 0 { plan.breakMinutes = value }
            }
        )
    }
}

/// The plan drawn to scale: study in cream, rest in green.
struct PlanBar: View {
    let plan: SessionPlan

    var body: some View {
        let phases = plan.phases
        let total = Double(phases.reduce(0) { $0 + $1.seconds })

        GeometryReader { geometry in
            let gap: CGFloat = 4
            let usable = geometry.size.width - gap * CGFloat(phases.count - 1)
            HStack(alignment: .top, spacing: gap) {
                ForEach(phases) { phase in
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule()
                            .fill(Theme.accent(for: phase.kind))
                            .frame(height: 8)
                        Text(Formatting.minutes(fromSeconds: phase.seconds))
                            .font(Theme.font(12, .medium))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: max(0, usable * CGFloat(Double(phase.seconds) / total)))
                }
            }
        }
        .frame(height: 30)
        .animation(.smooth(duration: 0.3), value: phases)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plan.summary)
    }
}
