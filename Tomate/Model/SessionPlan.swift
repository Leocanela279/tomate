import Foundation

enum PhaseKind: String, Codable {
    case focus
    case rest

    var title: String {
        switch self {
        case .focus: "Estudio"
        case .rest: "Descanso"
        }
    }
}

/// One stretch of a pomodoro: study or rest.
struct Phase: Codable, Hashable, Identifiable {
    /// Position inside the session (0, 1, 2…).
    let id: Int
    let kind: PhaseKind
    let seconds: Int
}

/// What the user sets up before starting or scheduling a pomodoro.
struct SessionPlan: Codable, Hashable {
    static let minuteRange = 25...90
    static let minuteStep = 5
    /// From this length on the session can be split with a break in the middle.
    static let splitThreshold = 60
    static let breakChoices = [15, 20]
    static let presets = [25, 45, 60, 90]

    var subject = ""
    var focusMinutes = 50
    var splitEnabled = false
    var breakMinutes = 15

    var canSplit: Bool { focusMinutes >= Self.splitThreshold }
    var isSplit: Bool { splitEnabled && canSplit }

    var title: String {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sesión de estudio" : trimmed
    }

    /// Study time is always `focusMinutes`. Splitting only adds a break in the middle.
    var phases: [Phase] {
        let total = focusMinutes * 60
        guard isSplit else { return [Phase(id: 0, kind: .focus, seconds: total)] }
        let firstHalf = total / 2
        return [
            Phase(id: 0, kind: .focus, seconds: firstHalf),
            Phase(id: 1, kind: .rest, seconds: breakMinutes * 60),
            Phase(id: 2, kind: .focus, seconds: total - firstHalf),
        ]
    }

    /// How long the whole session lasts: study plus the break in the middle, if any.
    var totalSeconds: Int { phases.reduce(0) { $0 + $1.seconds } }

    /// "50 min seguidos" or "90 min en dos bloques de 45 min con 15 min de descanso".
    var summary: String {
        guard isSplit else { return "\(focusMinutes) min seguidos" }
        let half = Formatting.minutes(fromSeconds: focusMinutes * 30)
        return "\(focusMinutes) min en dos bloques de \(half) con \(breakMinutes) min de descanso"
    }
}

// MARK: - Last used plan

extension SessionPlan {
    private static let draftKey = "tomate.draftPlan"

    static func loadDraft() -> SessionPlan {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let plan = try? JSONDecoder().decode(SessionPlan.self, from: data),
              minuteRange.contains(plan.focusMinutes)
        else { return SessionPlan() }
        return plan
    }

    func saveAsDraft() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftKey)
    }
}
