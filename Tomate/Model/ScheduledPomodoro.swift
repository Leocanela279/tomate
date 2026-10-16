import Foundation
import SwiftData

/// A pomodoro waiting for its time. It only exists until the user starts,
/// declines or cancels it; what happens next lives in the history.
@Model
final class ScheduledPomodoro {
    @Attribute(.unique) var id: UUID
    var fireDate: Date
    var subject: String
    var focusMinutes: Int
    var splitEnabled: Bool
    var breakMinutes: Int

    init(plan: SessionPlan, fireDate: Date) {
        self.id = UUID()
        self.fireDate = fireDate
        self.subject = plan.subject
        self.focusMinutes = plan.focusMinutes
        self.splitEnabled = plan.splitEnabled
        self.breakMinutes = plan.breakMinutes
    }

    var plan: SessionPlan {
        SessionPlan(subject: subject, focusMinutes: focusMinutes,
                    splitEnabled: splitEnabled, breakMinutes: breakMinutes)
    }

    /// From its start time to the end of its last block, break included.
    var interval: DateInterval {
        DateInterval(start: fireDate, duration: TimeInterval(plan.totalSeconds))
    }
}
