import AppKit
import Observation
import SwiftData
import UserNotifications

enum AppTab: String, CaseIterable, Identifiable {
    case timer
    case scheduled
    case history

    var id: Self { self }

    var title: String {
        switch self {
        case .timer: "Temporizador"
        case .scheduled: "Programados"
        case .history: "Historial"
        }
    }
}

/// Owns the app's shared pieces (storage, timer, notifications) and the actions
/// that involve more than one of them.
@MainActor
@Observable
final class AppModel {
    static let mainWindowID = "main"

    let persistence: Persistence
    let notifier: Notifier
    let engine: TimerEngine
    let focus: FocusAutomation

    var selectedTab: AppTab = .timer
    /// The scheduled pomodoro to point at when the user arrives from its notification.
    var highlightedScheduleID: UUID?
    /// The plan being set up on the timer screen. Remembered between launches.
    var draft = SessionPlan.loadDraft()

    /// Set by any SwiftUI view that has an `openWindow` action at hand.
    @ObservationIgnored var openMainWindow: (() -> Void)?

    var container: ModelContainer { persistence.container }
    private var context: ModelContext { persistence.context }

    init() {
        let persistence = Persistence()
        let notifier = Notifier()
        let engine = TimerEngine(persistence: persistence, notifier: notifier)
        let focus = FocusAutomation()
        self.persistence = persistence
        self.notifier = notifier
        self.engine = engine
        self.focus = focus

        // The demo never touches the Mac's Focus.
        guard !DemoData.isActive else { return }
        // Focus follows the timer: on for study blocks, off for breaks, pauses and the end.
        engine.onStudyingChange = { [weak focus] studying in
            focus?.studyingChanged(studying)
        }
        // If the app was closed while Tomate had Focus on and the session is over, turn it off.
        if !engine.isStudying { focus.releaseFocus() }
    }

    /// Runs once at launch.
    func bootstrap() async {
        await notifier.requestAuthorization()
        // Sample pomodoros must not send real reminders.
        guard !DemoData.isActive else { return }
        // Re-arm reminders in case they were created before notifications were allowed.
        let now = Date.now
        let upcoming = FetchDescriptor(predicate: #Predicate<ScheduledPomodoro> { $0.fireDate > now })
        for item in (try? context.fetch(upcoming)) ?? [] {
            notifier.scheduleReminder(id: item.id, plan: item.plan, at: item.fireDate)
        }
    }

    // MARK: Timer

    /// Starts the plan from the timer screen. `cancelling` are scheduled pomodoros
    /// it would overlap; the user has agreed to drop them.
    func startDraft(cancelling conflicts: [ScheduledPomodoro] = []) {
        for conflict in conflicts { remove(conflict) }
        engine.start(draft)
    }

    // MARK: Scheduling

    private var allScheduled: [ScheduledPomodoro] {
        (try? context.fetch(FetchDescriptor<ScheduledPomodoro>())) ?? []
    }

    /// Scheduled pomodoros that `plan` would run into if it started right now.
    func collisions(startingNow plan: SessionPlan, ignoring id: UUID? = nil) -> [ScheduledPomodoro] {
        Agenda.collisions(in: allScheduled, startingAt: .now,
                          duration: TimeInterval(plan.totalSeconds), ignoring: id)
    }

    /// Schedules `plan` at `date` unless it would overlap another pomodoro.
    /// The sheet already prevents that; this is the last line of defence.
    @discardableResult
    func schedule(_ plan: SessionPlan, at date: Date) -> Bool {
        // The picker only shows hours and minutes, so drop the hidden seconds:
        // "21:08" has to fire at 21:08:00, not at 21:08:56.
        let fireDate = Agenda.floorToMinute(date)
        let interval = DateInterval(start: fireDate, duration: TimeInterval(plan.totalSeconds))
        let agenda = Agenda(scheduled: allScheduled, running: engine.session)
        guard fireDate > .now, agenda.conflict(with: interval) == nil else { return false }

        let item = ScheduledPomodoro(plan: plan, fireDate: fireDate)
        let id = item.id
        context.insert(item)
        // Only promise a notification for something that is really stored.
        guard persistence.save() else { return false }
        notifier.scheduleReminder(id: id, plan: plan, at: fireDate)
        return true
    }

    /// Starts a scheduled pomodoro now. Any session in progress is stopped and saved first,
    /// and `cancelling` (other scheduled pomodoros it would overlap) are dropped.
    func start(_ item: ScheduledPomodoro, cancelling conflicts: [ScheduledPomodoro] = []) {
        let plan = item.plan
        for conflict in conflicts { remove(conflict) }
        remove(item)
        engine.start(plan, fromSchedule: true)
        selectedTab = .timer
    }

    /// Declines or cancels a scheduled pomodoro.
    func remove(_ item: ScheduledPomodoro) {
        notifier.cancelReminder(id: item.id)
        if highlightedScheduleID == item.id { highlightedScheduleID = nil }
        context.delete(item)
        persistence.save()
    }

    // MARK: Notifications

    func handleNotification(action: String, scheduledID: UUID?) {
        // Phase alerts carry no id: clicking one just brings the timer back.
        guard let scheduledID else {
            selectedTab = .timer
            presentMainWindow()
            return
        }
        guard let item = scheduledItem(id: scheduledID) else { return }

        switch action {
        case NotificationKey.acceptAction:
            if engine.isActive || !collisions(startingNow: item.plan, ignoring: item.id).isEmpty {
                // Starting it would overlap something: let the user choose in the app.
                point(at: item)
            } else {
                start(item)
                presentMainWindow()
            }
        case NotificationKey.declineAction:
            remove(item)
        default:
            // The banner itself was clicked.
            point(at: item)
        }
    }

    private func point(at item: ScheduledPomodoro) {
        highlightedScheduleID = item.id
        selectedTab = .scheduled
        presentMainWindow()
    }

    private func scheduledItem(id: UUID) -> ScheduledPomodoro? {
        var descriptor = FetchDescriptor(predicate: #Predicate<ScheduledPomodoro> { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: Window

    func presentMainWindow() {
        openMainWindow?()
        NSApp.activate()
    }
}
