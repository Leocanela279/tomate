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
        self.persistence = persistence
        self.notifier = notifier
        self.engine = TimerEngine(persistence: persistence, notifier: notifier)
    }

    /// Runs once at launch.
    func bootstrap() async {
        await notifier.requestAuthorization()
        // Re-arm reminders in case they were created before notifications were allowed.
        let now = Date.now
        let upcoming = FetchDescriptor(predicate: #Predicate<ScheduledPomodoro> { $0.fireDate > now })
        for item in (try? context.fetch(upcoming)) ?? [] {
            notifier.scheduleReminder(id: item.id, plan: item.plan, at: item.fireDate)
        }
    }

    // MARK: Timer

    func startDraft() {
        engine.start(draft)
    }

    // MARK: Scheduling

    func schedule(_ plan: SessionPlan, at date: Date) {
        let item = ScheduledPomodoro(plan: plan, fireDate: date)
        let id = item.id
        context.insert(item)
        // Only promise a notification for something that is really stored.
        guard persistence.save() else { return }
        notifier.scheduleReminder(id: id, plan: plan, at: date)
    }

    /// Starts a scheduled pomodoro now. Any session in progress is stopped and saved first.
    func start(_ item: ScheduledPomodoro) {
        let plan = item.plan
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
            if engine.isActive {
                // Something is already running: let the user choose in the app.
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
