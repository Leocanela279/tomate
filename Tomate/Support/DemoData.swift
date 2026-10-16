import Foundation
import SwiftData

/// Sample history and agenda for screenshots and the website demo.
///
/// Debug builds launched with `-TomateDemo` (Xcode ▸ Product ▸ Scheme ▸ Edit Scheme ▸ Arguments)
/// use an in-memory store filled with these sessions, so the real data on disk is never touched.
/// Reminders and Focus automation stay off in this mode.
enum DemoData {
    #if DEBUG
    static let isActive = true // TEMP: recording
    #else
    static let isActive = false
    #endif

    /// A finished session: days ago, start time, what, minutes planned, minutes studied, break.
    private struct Past {
        let daysAgo: Int
        let hour: Int
        let minute: Int
        let subject: String
        let planned: Int
        let studied: Int
        var breakMinutes = 0
        var fromSchedule = false
    }

    private static let history: [Past] = [
        Past(daysAgo: 6, hour: 10, minute: 0, subject: "Física", planned: 45, studied: 45),
        Past(daysAgo: 6, hour: 17, minute: 30, subject: "Inglés", planned: 50, studied: 50),
        Past(daysAgo: 5, hour: 9, minute: 30, subject: "Matemáticas II", planned: 90, studied: 90, breakMinutes: 15),
        Past(daysAgo: 5, hour: 16, minute: 0, subject: "Programación", planned: 50, studied: 50),
        Past(daysAgo: 4, hour: 18, minute: 0, subject: "Química", planned: 50, studied: 50),
        Past(daysAgo: 3, hour: 9, minute: 0, subject: "Matemáticas II", planned: 90, studied: 90, breakMinutes: 20),
        Past(daysAgo: 3, hour: 12, minute: 0, subject: "Física", planned: 60, studied: 60, breakMinutes: 15),
        Past(daysAgo: 3, hour: 19, minute: 0, subject: "Historia", planned: 45, studied: 30),
        Past(daysAgo: 2, hour: 10, minute: 0, subject: "Programación", planned: 90, studied: 90),
        Past(daysAgo: 2, hour: 18, minute: 30, subject: "Inglés", planned: 30, studied: 30, fromSchedule: true),
        Past(daysAgo: 1, hour: 11, minute: 0, subject: "Física", planned: 45, studied: 45),
        Past(daysAgo: 1, hour: 17, minute: 0, subject: "Matemáticas II", planned: 50, studied: 35),
        Past(daysAgo: 0, hour: 9, minute: 0, subject: "Matemáticas II", planned: 90, studied: 90, breakMinutes: 15),
        Past(daysAgo: 0, hour: 17, minute: 0, subject: "Inglés", planned: 45, studied: 45, fromSchedule: true),
    ]

    /// Coming up: days from now, start time and plan.
    private static let agenda: [(days: Int, hour: Int, minute: Int, plan: SessionPlan)] = [
        (1, 10, 0, SessionPlan(subject: "Física", focusMinutes: 60, splitEnabled: true, breakMinutes: 15)),
        (1, 16, 30, SessionPlan(subject: "Química", focusMinutes: 45)),
        (2, 11, 0, SessionPlan(subject: "Programación", focusMinutes: 90, splitEnabled: true, breakMinutes: 20)),
    ]

    @MainActor
    static func seed(_ context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func date(_ days: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        for past in history {
            let plan = SessionPlan(subject: past.subject, focusMinutes: past.planned,
                                   splitEnabled: past.breakMinutes > 0,
                                   breakMinutes: past.breakMinutes > 0 ? past.breakMinutes : 15)
            let start = date(-past.daysAgo, past.hour, past.minute)
            let session = ActiveSession(plan: plan, fromSchedule: past.fromSchedule, now: start)
            let completed = past.studied == past.planned
            let length = past.studied + (completed ? past.breakMinutes : 0)
            let record = FocusRecord(session: session,
                                     endedAt: start.addingTimeInterval(TimeInterval(length * 60)),
                                     completed: completed)
            record.focusedSeconds = past.studied * 60
            context.insert(record)
        }

        for item in agenda {
            context.insert(ScheduledPomodoro(plan: item.plan, fireDate: date(item.days, item.hour, item.minute)))
        }

        try? context.save()
    }
}
