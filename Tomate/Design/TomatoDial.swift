import SwiftUI

/// The countdown drawn as a tomato: a glossy body, a ring that empties clockwise
/// and the green calyx sitting where the ring ends.
struct TomatoDial<Center: View>: View {
    /// Share of the phase still to go, 1 → 0.
    let fraction: Double
    let kind: PhaseKind
    var size: CGFloat = 300
    @ViewBuilder var center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ring = size * 0.05
        let accent = Theme.accent(for: kind)

        ZStack {
            // Body of the fruit, slightly darker than the window, with a soft gloss.
            Circle()
                .fill(Theme.wine.opacity(0.22))
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(Theme.cream.opacity(0.10))
                        .frame(width: size * 0.32, height: size * 0.15)
                        .rotationEffect(.degrees(-28))
                        .blur(radius: size * 0.02)
                        .offset(x: size * 0.14, y: size * 0.14)
                }
                .padding(ring * 1.6)

            Circle()
                .stroke(Theme.cream.opacity(0.12), lineWidth: ring)
                .padding(ring / 2)

            Circle()
                .trim(from: 1 - min(max(fraction, 0), 1), to: 1)
                .stroke(accent, style: StrokeStyle(lineWidth: ring, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(ring / 2)
                .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)
                .animation(.easeInOut(duration: 0.4), value: kind)

            center

            Calyx()
                .fill(Theme.leaf)
                .frame(width: size * 0.26, height: size * 0.13)
                .overlay {
                    Capsule()
                        .fill(Theme.leaf)
                        .frame(width: max(2, size * 0.022), height: size * 0.075)
                        .rotationEffect(.degrees(12), anchor: .bottom)
                        .offset(y: -size * 0.04)
                }
                .shadow(color: Theme.wine.opacity(0.45), radius: size * 0.012, y: size * 0.006)
                .offset(y: -size / 2 + ring / 2)
        }
        .frame(width: size, height: size)
    }
}

extension TomatoDial where Center == EmptyView {
    init(fraction: Double, kind: PhaseKind, size: CGFloat = 300) {
        self.init(fraction: fraction, kind: kind, size: size) { EmptyView() }
    }
}

/// The star of sepals on top of a tomato, flattened as if seen from the front.
struct Calyx: Shape {
    var sepals = 5

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        let step = 2 * CGFloat.pi / CGFloat(sepals)
        let start = -CGFloat.pi / 2

        func point(_ angle: CGFloat, _ scale: CGFloat) -> CGPoint {
            CGPoint(x: center.x + rx * scale * cos(angle), y: center.y + ry * scale * sin(angle))
        }

        var path = Path()
        path.move(to: point(start - step / 2, 0.28))
        for index in 0..<sepals {
            let tip = start + CGFloat(index) * step
            path.addQuadCurve(to: point(tip, 1), control: point(tip - step * 0.28, 0.72))
            path.addQuadCurve(to: point(tip + step / 2, 0.28), control: point(tip + step * 0.28, 0.72))
        }
        path.closeSubpath()
        return path
    }
}
