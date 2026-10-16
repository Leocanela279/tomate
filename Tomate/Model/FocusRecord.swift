import Foundation
import SwiftData

/// A finished or stopped pomodoro, shown in the history.
@Model
final class FocusRecord {
    var id: UUID
    var subject: String
    var startedAt: Date
    var endedAt: Date
    var plannedMinutes: Int
    var focusedSeconds: Int
    /// 0 when the session was done in one go.
    var breakMinutes: Int
    var completed: Bool
    var fromSchedule: Bool

    init(session: ActiveSession, endedAt: Date, completed: Bool) {
        self.id = UUID()
        self.subject = session.plan.title
        self.startedAt = session.startedAt
        self.endedAt = endedAt
        self.plannedMinutes = session.plan.focusMinutes
        self.focusedSeconds = session.focusedSeconds
        self.breakMinutes = session.plan.isSplit ? session.plan.breakMinutes : 0
        self.completed = completed
        self.fromSchedule = session.fromSchedule
    }
}
