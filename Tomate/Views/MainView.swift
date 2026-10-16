import AppKit
import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Query private var scheduled: [ScheduledPomodoro]

    @AppStorage(ThemeMode.storageKey) private var mode: ThemeMode = .tomato
    /// The theme being covered while the new one grows out of the button.
    @State private var outgoingMode: ThemeMode?

    /// Switching tabs: the old screen leaves at once and the new one fades in,
    /// so the two never show on top of each other.
    private static let screenChange = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.25)),
        removal: .identity
    )

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            // Tabs centred, theme button at the far right on the same line.
            ZStack {
                TabSwitcher(selection: $model.selectedTab, badges: [.scheduled: scheduled.count])
                HStack(spacing: 8) {
                    Spacer()
                    SettingsLink {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(GlassIconButtonStyle(size: 36))
                    .help("Ajustes")
                    .accessibilityLabel("Ajustes")
                    ThemeToggle(mode: mode, action: toggleTheme)
                        .disabled(outgoingMode != nil)
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 14)

            Group {
                switch model.selectedTab {
                case .timer: TimerScreen().transition(Self.screenChange)
                case .scheduled: ScheduleScreen().transition(Self.screenChange)
                case .history: HistoryScreen().transition(Self.screenChange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if model.persistence.lastSaveFailed {
                NoticeBanner(icon: "externaldrive.badge.exclamationmark",
                             message: "No se pudo guardar. Comprueba que tu Mac tenga espacio libre en el disco.")
            } else if model.notifier.isDenied {
                NoticeBanner(icon: "bell.slash.fill",
                             message: "Las notificaciones están desactivadas. Sin ellas no podremos avisarte de los pomodoros programados.",
                             actionTitle: "Abrir Ajustes") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .backgroundPreferenceValue(ThemeToggleAnchorKey.self) { anchor in
            GeometryReader { proxy in
                // The button's centre, turned into window coordinates for the background.
                let frame = proxy.frame(in: .global)
                let local = anchor.map { proxy[$0] } ?? CGPoint(x: proxy.size.width - 38, y: 34)
                ThemedBackground(mode: mode, outgoing: outgoingMode,
                                 origin: CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)) {
                    outgoingMode = nil
                }
            }
        }
        .foregroundStyle(Theme.text)
        .tint(mode.palette.accentFill)
        .environment(\.palette, mode.palette)
        .preferredColorScheme(.dark)
        .environment(\.locale, .app)
        .onAppear {
            model.openMainWindow = { openWindow(id: AppModel.mainWindowID) }
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
        .onDisappear {
            // With the window closed, Tomate lives only in the menu bar.
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// The new background grows from the button (ThemedBackground) while text and
    /// controls fade to the new palette.
    private func toggleTheme() {
        let current = mode
        withAnimation(.easeInOut(duration: 0.5)) {
            outgoingMode = current
            mode = current.toggled
        }
    }
}

/// The three tabs on a glass bar. One glass pill slides under the selected tab:
/// it is a single view that changes position and width, so it glides instead of jumping.
private struct TabSwitcher: View {
    @Binding var selection: AppTab
    var badges: [AppTab: Int] = [:]

    /// A soft spring with a hint of bounce, like a drop of liquid settling.
    private static let slide = Animation.spring(duration: 0.45, bounce: 0.18)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    // The same transaction moves the pill, fades the label colours
                    // and cross-fades the screen below.
                    withAnimation(Self.slide) { selection = tab }
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.title)
                        if let count = badges[tab], count > 0 {
                            Text("\(count)")
                                .font(Theme.font(11, .bold))
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .frame(minHeight: 17)
                                .background(Theme.text.opacity(0.16), in: Capsule())
                        }
                    }
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(isSelected ? Theme.text : Theme.secondaryText)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 32)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .anchorPreference(key: TabBoundsKey.self, value: .bounds) { [tab: $0] }
                .keyboardShortcut(tab.shortcut, modifiers: .command)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .backgroundPreferenceValue(TabBoundsKey.self) { bounds in
            GeometryReader { proxy in
                if let anchor = bounds[selection] {
                    let rect = proxy[anchor]
                    GlassPill()
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
        .padding(4)
        .glass(in: Capsule())
    }
}

/// Where each tab is, so the pill can sit under the selected one.
private struct TabBoundsKey: PreferenceKey {
    static let defaultValue: [AppTab: Anchor<CGRect>] = [:]

    static func reduce(value: inout [AppTab: Anchor<CGRect>], nextValue: () -> [AppTab: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// A small bead of glass: a tinted translucent body, light catching the top edge,
/// a bright rim and a soft shadow underneath.
private struct GlassPill: View {
    var body: some View {
        Capsule()
            .fill(Theme.accentFill.opacity(0.24))
            .overlay {
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                Capsule()
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                                 startPoint: .top, endPoint: .bottom),
                                  lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
    }
}

private extension AppTab {
    /// ⌘1, ⌘2, ⌘3
    var shortcut: KeyEquivalent {
        switch self {
        case .timer: return KeyEquivalent("1")
        case .scheduled: return KeyEquivalent("2")
        case .history: return KeyEquivalent("3")
        }
    }
}

/// A problem the user should know about, with an optional way to fix it.
private struct NoticeBanner: View {
    let icon: String
    let message: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
            Text(message)
                .font(Theme.font(13))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(GlassButtonStyle())
            }
        }
        .frame(minHeight: 38)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .panel(cornerRadius: 18)
        .padding([.horizontal, .bottom], 20)
    }
}
