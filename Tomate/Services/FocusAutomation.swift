import AppKit
import Foundation
import Observation

/// Turns the Mac's Focus (No molestar, Estudio…) on while a study block runs and off for
/// breaks and when the pomodoro ends.
///
/// macOS has no public API for apps to change Focus, so Tomate runs two shortcuts the user
/// creates once in the Shortcuts app. They are run through "Shortcuts Events", which works
/// in the background without opening Shortcuts.
@MainActor
@Observable
final class FocusAutomation {
    static let studyShortcut = "Tomate Estudiar"
    static let restShortcut = "Tomate Descansar"

    private static let enabledKey = "tomate.focusAutomation"
    /// Tomate turned Focus on and has not turned it off yet (survives quitting the app).
    private static let ownsFocusKey = "tomate.focusOwnedByTomate"

    private(set) var isEnabled: Bool
    /// What went wrong the last time a shortcut ran, in words for the user.
    private(set) var problem: String?
    private(set) var isTesting = false
    private(set) var testPassed = false

    @ObservationIgnored private let queue = DispatchQueue(label: "tomate.shortcuts")

    private var ownsFocus: Bool {
        get { UserDefaults.standard.bool(forKey: Self.ownsFocusKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.ownsFocusKey) }
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if !enabled { releaseFocus() }
    }

    // MARK: Timer events

    /// Called by the timer whenever the user starts or stops actively studying.
    func studyingChanged(_ studying: Bool) {
        guard isEnabled else { return }
        if studying {
            ownsFocus = true
            run(Self.studyShortcut)
        } else {
            releaseFocus()
        }
    }

    /// Turns Focus off only if Tomate was the one that turned it on.
    func releaseFocus() {
        guard ownsFocus else { return }
        ownsFocus = false
        run(Self.restShortcut)
    }

    // MARK: Test from Settings

    /// Runs "Estudiar", waits a moment and runs "Descansar", so the user sees both work.
    func test() {
        guard !isTesting else { return }
        isTesting = true
        testPassed = false
        problem = nil
        run(Self.studyShortcut) { [weak self] error in
            guard let self else { return }
            guard error == nil else {
                self.isTesting = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.run(Self.restShortcut) { [weak self] error in
                    self?.isTesting = false
                    self?.testPassed = error == nil
                }
            }
        }
    }

    // MARK: Running shortcuts

    private func run(_ name: String, then completion: ((String?) -> Void)? = nil) {
        let source = "tell application id \"com.apple.shortcuts.events\" to run shortcut \"\(name)\""
        // AppleScript blocks until the shortcut finishes, so keep it off the main thread.
        queue.async {
            var errorInfo: NSDictionary?
            _ = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
            let message = errorInfo.map { Self.describe($0, shortcut: name) }
            DispatchQueue.main.async { [weak self] in
                self?.problem = message
                completion?(message)
            }
        }
    }

    nonisolated private static func describe(_ info: NSDictionary, shortcut: String) -> String {
        let number = info[NSAppleScript.errorNumber] as? Int ?? 0
        switch number {
        case -1743:
            return "Tomate no tiene permiso para usar Atajos. Actívalo en Ajustes del Sistema → Privacidad y seguridad → Automatización → Tomate."
        case -1728, -1719, -2753:
            return "No encuentro el atajo «\(shortcut)». Comprueba que existe y que se llama exactamente así."
        default:
            let detail = info[NSAppleScript.errorMessage] as? String ?? "error \(number)"
            return "No se pudo ejecutar «\(shortcut)»: \(detail)"
        }
    }
}
