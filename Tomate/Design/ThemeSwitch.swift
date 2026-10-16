import SwiftUI

/// Small round button that switches between the tomato and dark looks.
/// It publishes its centre so the new theme can grow out of it.
struct ThemeToggle: View {
    let mode: ThemeMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: mode == .tomato ? "moon.fill" : "sun.max.fill")
                .contentTransition(.symbolEffect(.replace.downUp))
                .symbolEffect(.bounce, value: mode)
        }
        .buttonStyle(GlassIconButtonStyle(size: 36))
        .help(mode == .tomato ? "Cambiar a modo oscuro" : "Cambiar a modo tomate")
        .accessibilityLabel(mode == .tomato ? "Cambiar a modo oscuro" : "Cambiar a modo tomate")
        .anchorPreference(key: ThemeToggleAnchorKey.self, value: .center) { $0 }
    }
}

/// The centre of the theme button, resolved by whoever draws the background.
struct ThemeToggleAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil

    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

/// The window background. After a theme change the new background grows as a soft-edged
/// circle from `origin` over the old one, which is dropped once it is fully covered.
struct ThemedBackground: View {
    let mode: ThemeMode
    /// The theme being covered, while the reveal runs.
    let outgoing: ThemeMode?
    /// Centre of the theme button, in window coordinates.
    let origin: CGPoint
    let onRevealFinished: () -> Void

    var body: some View {
        GeometryReader { proxy in
            // The background reaches under the title bar, so convert from window coordinates.
            let frame = proxy.frame(in: .global)
            let center = CGPoint(x: origin.x - frame.minX, y: origin.y - frame.minY)

            ZStack {
                if let outgoing {
                    PaletteBackground(palette: outgoing.palette)
                        .transition(.identity)
                }
                PaletteBackground(palette: mode.palette)
                    .modifier(CircleReveal(center: center, size: proxy.size,
                                           animated: outgoing != nil, onFinished: onRevealFinished))
                    // A new identity per mode restarts the reveal from zero.
                    .id(mode)
                    .transition(.identity)
            }
        }
        .ignoresSafeArea()
    }
}

/// Masks the content with a circle centred on `center` that grows until it covers everything.
private struct CircleReveal: ViewModifier {
    let center: CGPoint
    let size: CGSize
    let onFinished: () -> Void
    @State private var progress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Share of the circle that is fully opaque; the rest is the soft edge.
    private static let solid: CGFloat = 0.8

    init(center: CGPoint, size: CGSize, animated: Bool, onFinished: @escaping () -> Void) {
        self.center = center
        self.size = size
        self.onFinished = onFinished
        _progress = State(initialValue: animated ? 0 : 1)
    }

    func body(content: Content) -> some View {
        // Big enough that the opaque part reaches the farthest corner.
        let reach = farthestCorner / (Self.solid / 2) * 1.02
        let diameter = max(1, reach * progress)

        content
            .mask {
                Ellipse()
                    .fill(EllipticalGradient(stops: [.init(color: .black, location: Self.solid),
                                                     .init(color: .clear, location: 1)],
                                             center: .center,
                                             startRadiusFraction: 0,
                                             endRadiusFraction: 0.5))
                    .frame(width: diameter, height: diameter)
                    .position(center)
            }
            .onAppear {
                guard progress < 1 else { return }
                if reduceMotion {
                    progress = 1
                    onFinished()
                    return
                }
                withAnimation(.easeInOut(duration: 0.75)) {
                    progress = 1
                } completion: {
                    onFinished()
                }
            }
    }

    private var farthestCorner: CGFloat {
        let dx = max(center.x, size.width - center.x)
        let dy = max(center.y, size.height - center.y)
        return (dx * dx + dy * dy).squareRoot()
    }
}
