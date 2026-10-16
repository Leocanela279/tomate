import AppKit
import SwiftUI

/// Ajustes (⌘,). For now one section: turning the Mac's Focus on while studying.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(ThemeMode.storageKey) private var mode: ThemeMode = .tomato

    var body: some View {
        FocusSettings(focus: model.focus)
            .padding(28)
            .frame(width: 520)
            .background(TomatoBackground())
            .foregroundStyle(Theme.text)
            .tint(mode.palette.accentFill)
            .environment(\.palette, mode.palette)
            .preferredColorScheme(.dark)
            .environment(\.locale, .app)
    }
}

private struct FocusSettings: View {
    let focus: FocusAutomation

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Concentración")
                    .font(Theme.font(24, .semibold))
                Text("Tomate puede activar tu modo Concentración mientras estudias y quitarlo en los descansos, al pausar y al terminar, para que te lleguen los avisos.")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(isOn: Binding(get: { focus.isEnabled }, set: { focus.setEnabled($0) })) {
                Text("Activar Concentración al estudiar")
                    .font(Theme.font(14, .semibold))
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .panel(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 12) {
                Text("Se configura una vez")
                    .font(Theme.font(14, .semibold))
                    .foregroundStyle(Theme.secondaryText)
                step(1, "En Atajos, crea un atajo llamado «\(FocusAutomation.studyShortcut)» con la acción de Concentración en «Activar» y elige tu modo (No molestar o uno de estudio).")
                step(2, "Crea otro llamado «\(FocusAutomation.restShortcut)» con la misma acción en «Desactivar».")
                step(3, "En Ajustes del Sistema → Concentración → tu modo → Apps permitidas, añade Tomate. Así sus avisos te llegan aunque la Concentración esté activa.")
                step(4, "Pulsa «Probar». La primera vez macOS te pedirá permiso para que Tomate use Atajos.")
            }

            HStack(spacing: 8) {
                Button("Abrir Atajos") { open("shortcuts://") }
                    .buttonStyle(GlassButtonStyle())
                Button("Ajustes de Concentración") { open("x-apple.systempreferences:com.apple.Focus-Settings.extension") }
                    .buttonStyle(GlassButtonStyle())
                Spacer()
                Button(testTitle) { focus.test() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(focus.isTesting)
            }

            status
        }
    }

    private var testTitle: String {
        focus.isTesting ? "Probando…" : "Probar"
    }

    @ViewBuilder
    private var status: some View {
        if let problem = focus.problem {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .font(Theme.font(13, .medium))
                .fixedSize(horizontal: false, vertical: true)
        } else if focus.isTesting {
            Text("Activando la Concentración… en unos segundos se desactivará.")
                .font(Theme.font(13))
                .foregroundStyle(Theme.secondaryText)
        } else if focus.testPassed {
            Label("Funciona: la Concentración se activó y se desactivó.", systemImage: "checkmark.circle.fill")
                .font(Theme.font(13, .medium))
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(Theme.font(12, .bold))
                .monospacedDigit()
                .frame(width: 20, height: 20)
                .background(Theme.field, in: Circle())
            Text(text)
                .font(Theme.font(13))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}
