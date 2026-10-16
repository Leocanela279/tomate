import SwiftUI

/// Tomate's palette and type. Every window is the red of a ripe tomato; cream is for
/// text and the clock, green is only for the calyx and for rest phases.
enum Theme {
    static let tomato = Color(red: 0.749, green: 0.149, blue: 0.125)      // #BF2620
    static let tomatoDeep = Color(red: 0.431, green: 0.039, blue: 0.059)  // #6E0A0F
    static let sheen = Color(red: 1.0, green: 0.435, blue: 0.322)         // #FF6F52
    static let wine = Color(red: 0.290, green: 0.024, blue: 0.039)        // #4A060A
    static let cream = Color(red: 1.0, green: 0.945, blue: 0.925)         // #FFF1EC
    static let leaf = Color(red: 0.388, green: 0.769, blue: 0.431)        // #63C46E

    static let secondaryText = Theme.cream.opacity(0.78)
    static let tertiaryText = Theme.cream.opacity(0.58)

    static func accent(for kind: PhaseKind) -> Color {
        kind == .focus ? cream : leaf
    }

    /// SF Rounded everywhere: soft like the fruit, with tabular digits where it counts.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Full-bleed tomato skin: a deep red gradient with a soft highlight up and to the left.
struct TomatoBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.tomato, Theme.tomatoDeep], startPoint: .top, endPoint: .bottom)
            .overlay {
                RadialGradient(colors: [Theme.sheen.opacity(0.30), .clear],
                               center: UnitPoint(x: 0.25, y: 0.22),
                               startRadius: 0, endRadius: 480)
            }
            .ignoresSafeArea()
    }
}

extension View {
    /// Quiet container for content. Most surfaces use this; glass is kept for controls.
    func panel(cornerRadius: CGFloat = 24) -> some View {
        background(Theme.wine.opacity(0.3), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Liquid Glass on macOS 26 and later, frosted material on earlier systems.
    @ViewBuilder
    func glass<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            frostedFallback(in: shape)
        }
        #else
        frostedFallback(in: shape)
        #endif
    }

    private func frostedFallback<S: Shape>(in shape: S) -> some View {
        background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.stroke(Theme.cream.opacity(0.14), lineWidth: 1)
            }
    }
}
