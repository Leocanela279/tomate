import Foundation

/// The time already taken by pomodoros, and the rule that keeps them from overlapping:
/// two pomodoros can follow each other back to back, but never share a minute.
struct Agenda {
    struct Slot {
        /// nil for the pomodoro that is running now.
        let id: UUID?
        let title: String
        let interval: DateInterval
    }

    /// Taken slots that have not finished yet, earliest first.
    let slots: [Slot]

    init(scheduled: [ScheduledPomodoro], running: ActiveSession?, now: Date = .now) {
        var slots = scheduled
            .map { Slot(id: $0.id, title: $0.plan.title, interval: $0.interval) }
            .filter { $0.interval.end > now }
        if let running {
            let end = max(now, running.expectedEnd(from: now))
            slots.append(Slot(id: nil, title: running.plan.title,
                              interval: DateInterval(start: now, end: end)))
        }
        self.slots = slots.sorted { $0.interval.start < $1.interval.start }
    }

    /// The first taken slot that `interval` would overlap, if any.
    func conflict(with interval: DateInterval) -> Slot? {
        slots.first { Self.overlap($0.interval, interval) }
    }

    /// The earliest whole minute at or after `start` where `duration` fits without overlapping.
    func firstFreeStart(for duration: TimeInterval, from start: Date) -> Date {
        var candidate = Self.ceilToMinute(start)
        while let blocking = conflict(with: DateInterval(start: candidate, duration: duration)) {
            candidate = Self.ceilToMinute(blocking.interval.end)
        }
        return candidate
    }

    /// Scheduled pomodoros that a session of `duration` starting at `now` would run into.
    static func collisions(in scheduled: [ScheduledPomodoro], startingAt now: Date,
                           duration: TimeInterval, ignoring ignoredID: UUID? = nil) -> [ScheduledPomodoro] {
        let end = now.addingTimeInterval(duration)
        return scheduled
            .filter { $0.id != ignoredID && $0.fireDate > now && $0.fireDate < end }
            .sorted { $0.fireDate < $1.fireDate }
    }

    /// Back to back (one ends 22:00, the next starts 22:00) is not an overlap.
    static func overlap(_ a: DateInterval, _ b: DateInterval) -> Bool {
        a.start < b.end && b.start < a.end
    }

    /// Scheduled times are whole minutes: 21:08:56 → 21:08:00.
    static func floorToMinute(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    }

    static func ceilToMinute(_ date: Date) -> Date {
        guard let minute = Calendar.current.dateInterval(of: .minute, for: date) else { return date }
        return minute.start == date ? date : minute.end
    }
}
