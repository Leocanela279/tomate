import Foundation

/// The pomodoro in progress.
///
/// Time is stored as dates rather than as a counter, so the countdown stays
/// exact after the Mac sleeps, after App Nap, or after quitting and reopening.
struct ActiveSession: Codable, Equatable {
    let id: UUID
    let plan: SessionPlan
    let phases: [Phase]
    let startedAt: Date
    let fromSchedule: Bool
    var phaseIndex: Int
    /// Set while running: when the current phase ends.
    var phaseEndsAt: Date?
    /// Set while paused: seconds left in the current phase.
    var pausedRemaining: Int?
    /// Study seconds from phases already behind.
    var focusedSeconds: Int

    init(plan: SessionPlan, fromSchedule: Bool, now: Date = .now) {
        let phases = plan.phases
        self.id = UUID()
        self.plan = plan
        self.phases = phases
        self.startedAt = now
        self.fromSchedule = fromSchedule
        self.phaseIndex = 0
        self.phaseEndsAt = now.addingTimeInterval(TimeInterval(phases.first?.seconds ?? 0))
        self.pausedRemaining = nil
        self.focusedSeconds = 0
    }

    var currentPhase: Phase { phases[phaseIndex] }
    var isPaused: Bool { phaseEndsAt == nil }
    var isLastPhase: Bool { phaseIndex == phases.count - 1 }

    func remaining(at now: Date) -> Int {
        if let end = phaseEndsAt {
            return max(0, Int(ceil(end.timeIntervalSince(now))))
        }
        return pausedRemaining ?? currentPhase.seconds
    }

    /// When the whole session ends if nothing is paused or skipped from now on.
    func expectedEnd(from now: Date) -> Date {
        let later = phases.dropFirst(phaseIndex + 1).reduce(0) { $0 + $1.seconds }
        return now.addingTimeInterval(TimeInterval(remaining(at: now) + later))
    }

    /// Number of the current study block (1 or 2) in a split session.
    var blockNumber: Int { phases[...phaseIndex].filter { $0.kind == .focus }.count }
    var blockCount: Int { phases.filter { $0.kind == .focus }.count }
}

// MARK: - Survives quitting the app

extension ActiveSession {
    private static let storageKey = "tomate.activeSession"

    static func loadSaved() -> ActiveSession? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let session = try? JSONDecoder().decode(ActiveSession.self, from: data),
              session.phases.indices.contains(session.phaseIndex)
        else { return nil }
        return session
    }

    static func save(_ session: ActiveSession?) {
        if let session, let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
