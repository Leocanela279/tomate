import AppKit
import SwiftData
import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Query private var scheduled: [ScheduledPomodoro]

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            TabSwitcher(selection: $model.selectedTab, badges: [.scheduled: scheduled.count])
                .padding(.top, 14)

            Group {
                switch model.selectedTab {
                case .timer: TimerScreen()
                case .scheduled: ScheduleScreen()
                case .history: HistoryScreen()
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
        .background(TomatoBackground())
        .foregroundStyle(Theme.cream)
        .tint(Theme.cream)
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
}

private struct TabSwitcher: View {
    @Binding var selection: AppTab
    var badges: [AppTab: Int] = [:]
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.title)
                        if let count = badges[tab], count > 0 {
                            Text("\(count)")
                                .font(Theme.font(11, .bold))
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .frame(minHeight: 17)
                                .background(isSelected ? Theme.tomato.opacity(0.18) : Theme.cream.opacity(0.18),
                                            in: Capsule())
                        }
                    }
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(isSelected ? Theme.tomatoDeep : Theme.cream.opacity(0.85))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 32)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Theme.cream)
                                .matchedGeometryEffect(id: "tab", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(tab.shortcut, modifiers: .command)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .glass(in: Capsule())
        .animation(.snappy(duration: 0.3), value: selection)
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
