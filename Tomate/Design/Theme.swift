import SwiftUI

// MARK: - Modes

/// The two looks of Tomate. The tomato one is the original; dark keeps the fruit as the accent.
enum ThemeMode: String, CaseIterable {
    case tomato
    case dark

    static let storageKey = "tomate.theme"

    var palette: Palette {
        switch self {
        case .tomato: .tomato
        case .dark: .dark
        }
    }

    var toggled: ThemeMode { self == .tomato ? .dark : .tomato }
}

// MARK: - Palette

/// Every color the interface uses, by role. Views never pick raw colors:
/// they use `Theme.text`, `Theme.surface`… which resolve against the active palette.
struct Palette {
    var backgroundTop: Color
    var backgroundBottom: Color
    var glow: Color
    var text: Color
    var secondaryText: Color
    var tertiaryText: Color
    /// Quiet containers (panels, rows).
    var surface: Color
    /// Inputs, segmented tracks, chips.
    var field: Color
    /// The one solid fill: primary button, selected segment, chart bars.
    var accentFill: Color
    var onAccent: Color
    /// Study phase: the dial ring and markers.
    var focus: Color
    /// Rest phase. Green in both modes, like the calyx.
    var rest: Color
    var dialBody: Color
    var shadow: Color

    private static let cream = Color(red: 1.0, green: 0.945, blue: 0.925)      // #FFF1EC
    private static let leaf = Color(red: 0.388, green: 0.769, blue: 0.431)     // #63C46E
    private static let wine = Color(red: 0.290, green: 0.024, blue: 0.039)     // #4A060A
    private static let tomatoRed = Color(red: 0.898, green: 0.224, blue: 0.180) // #E5392E

    /// The original look: the whole window is a ripe tomato.
    static let tomato = Palette(
        backgroundTop: Color(red: 0.749, green: 0.149, blue: 0.125),    // #BF2620
        backgroundBottom: Color(red: 0.431, green: 0.039, blue: 0.059), // #6E0A0F
        glow: Color(red: 1.0, green: 0.435, blue: 0.322).opacity(0.30), // #FF6F52
        text: cream,
        secondaryText: cream.opacity(0.78),
        tertiaryText: cream.opacity(0.58),
        surface: wine.opacity(0.30),
        field: wine.opacity(0.35),
        accentFill: cream,
        onAccent: Color(red: 0.431, green: 0.039, blue: 0.059),
        focus: cream,
        rest: leaf,
        dialBody: wine.opacity(0.22),
        shadow: wine
    )

    /// Night look: a near-black wine background with the tomato as the accent.
    static let dark = Palette(
        backgroundTop: Color(red: 0.129, green: 0.071, blue: 0.075),    // #211213
        backgroundBottom: Color(red: 0.059, green: 0.035, blue: 0.039), // #0F090A
        glow: tomatoRed.opacity(0.16),
        text: cream,
        secondaryText: cream.opacity(0.70),
        tertiaryText: cream.opacity(0.50),
        surface: Color.white.opacity(0.05),
        field: Color.white.opacity(0.07),
        accentFill: tomatoRed,
        onAccent: cream,
        focus: tomatoRed,
        rest: leaf,
        dialBody: tomatoRed.opacity(0.10),
        shadow: .black
    )

    static let calyx = leaf

    func color(for token: PaletteToken) -> Color {
        switch token {
        case .text: text
        case .secondaryText: secondaryText
        case .tertiaryText: tertiaryText
        case .surface: surface
        case .field: field
        case .accentFill: accentFill
        case .onAccent: onAccent
        case .focus: focus
        case .rest: rest
        case .dialBody: dialBody
        }
    }
}

enum PaletteToken {
    case text, secondaryText, tertiaryText, surface, field, accentFill, onAccent, focus, rest, dialBody
}

/// A palette role usable anywhere SwiftUI takes a ShapeStyle. It is resolved where it is
/// drawn, so a theme change repaints the whole interface without passing colors around.
struct PaletteColor: ShapeStyle {
    let token: PaletteToken

    func resolve(in environment: EnvironmentValues) -> Color {
        environment.palette.color(for: token)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.tomato
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Tokens and type

enum Theme {
    static let text = PaletteColor(token: .text)
    static let secondaryText = PaletteColor(token: .secondaryText)
    static let tertiaryText = PaletteColor(token: .tertiaryText)
    static let surface = PaletteColor(token: .surface)
    static let field = PaletteColor(token: .field)
    static let accentFill = PaletteColor(token: .accentFill)
    static let onAccent = PaletteColor(token: .onAccent)
    static let dialBody = PaletteColor(token: .dialBody)

    static func phase(_ kind: PhaseKind) -> PaletteColor {
        PaletteColor(token: kind == .focus ? .focus : .rest)
    }

    /// SF Rounded everywhere: soft like the fruit, with tabular digits where it counts.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Backgrounds

/// The gradient of one palette, with a soft highlight up and to the left.
struct PaletteBackground: View {
    let palette: Palette

    var body: some View {
        LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                       startPoint: .top, endPoint: .bottom)
            .overlay {
                RadialGradient(colors: [palette.glow, .clear],
                               center: UnitPoint(x: 0.25, y: 0.22),
                               startRadius: 0, endRadius: 480)
            }
    }
}

/// Full-bleed background in the active palette (sheets and the menu bar panel).
struct TomatoBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        PaletteBackground(palette: palette)
            .ignoresSafeArea()
    }
}

// MARK: - Surfaces

extension View {
    /// Quiet container for content. Most surfaces use this; glass is kept for controls.
    func panel(cornerRadius: CGFloat = 24) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
                shape.stroke(Theme.text.opacity(0.14), lineWidth: 1)
            }
    }
}
