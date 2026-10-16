import SwiftUI

// MARK: - Buttons

/// The one solid control on screen: an accent capsule (cream on tomato, tomato on dark).
struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration, fullWidth: fullWidth)
    }

    private struct PrimaryButton: View {
        let configuration: ButtonStyleConfiguration
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .labelStyle(.titleAndIcon)
                .font(Theme.font(15, .semibold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 22)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
                .background(Theme.accentFill, in: Capsule())
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// Secondary action on glass.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(Theme.font(14, .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18)
            .frame(minHeight: 38)
            .glass(in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Round glass button for the session controls (skip, stop).
struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.34, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(width: size, height: size)
            .glass(in: Circle())
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Text-only button for low-emphasis actions: cancel, discard, open.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(14, .medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Small pill for quick picks such as "En 1 h".
struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(13, .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(Theme.field, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Segmented choice

struct Choice<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    var id: Value { value }
}

/// A row of mutually exclusive options; the selected one is an accent pill that slides.
struct ChoiceControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [Choice<Value>]
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(Theme.font(13, .semibold))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Theme.onAccent : Theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.accentFill)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.field, in: Capsule())
        .animation(.snappy(duration: 0.25), value: selection)
    }
}

// MARK: - Empty states

struct EmptyState<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            TomatoDial(fraction: 0, kind: .focus, size: 84)
                .padding(.bottom, 6)
            Text(title)
                .font(Theme.font(22, .semibold))
            Text(message)
                .font(Theme.font(14))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            actions
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EmptyState where Actions == EmptyView {
    init(title: String, message: String) {
        self.init(title: title, message: message) { EmptyView() }
    }
}
