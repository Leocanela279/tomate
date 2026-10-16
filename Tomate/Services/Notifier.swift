import Foundation
import Observation
import UserNotifications

/// Identifiers shared by the notification content and the delegate that answers it.
enum NotificationKey {
    static let scheduledCategory = "tomate.scheduled"
    static let acceptAction = "tomate.accept"
    static let declineAction = "tomate.decline"
    static let scheduledID = "scheduledID"
}

/// Local notifications: alerts when a phase of the running pomodoro ends, and
/// reminders with Empezar / Rechazar buttons for scheduled ones.
@MainActor
@Observable
final class Notifier {
    private(set) var status: UNAuthorizationStatus = .notDetermined

    var isDenied: Bool { status == .denied }

    private var center: UNUserNotificationCenter { .current() }

    /// A session has at most three phases; one id per phase position.
    private static let phaseAlertIDs = (0..<4).map { "tomate.phase.\($0)" }

    // MARK: Setup

    func registerCategories() {
        let accept = UNNotificationAction(identifier: NotificationKey.acceptAction,
                                          title: "Empezar", options: [.foreground])
        let decline = UNNotificationAction(identifier: NotificationKey.declineAction,
                                           title: "Rechazar", options: [.destructive])
        let category = UNNotificationCategory(identifier: NotificationKey.scheduledCategory,
                                              actions: [accept, decline],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refreshStatus()
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        status = settings.authorizationStatus
    }

    // MARK: Running session

    /// Schedules an alert for the end of the current phase and of every phase after it,
    /// so they arrive on time even if the app is closed or the Mac was asleep.
    func schedulePhaseAlerts(for session: ActiveSession) {
        cancelPhaseAlerts()
        guard var end = session.phaseEndsAt else { return }
        for index in session.phaseIndex..<session.phases.count {
            if index > session.phaseIndex {
                end += TimeInterval(session.phases[index].seconds)
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow),
                                                            repeats: false)
            let request = UNNotificationRequest(identifier: Self.phaseAlertIDs[index],
                                                content: phaseEndContent(index: index, of: session),
                                                trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    func cancelPhaseAlerts() {
        center.removePendingNotificationRequests(withIdentifiers: Self.phaseAlertIDs)
    }

    private func phaseEndContent(index: Int, of session: ActiveSession) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        let phases = session.phases
        if phases.indices.contains(index + 1) {
            let next = phases[index + 1]
            let length = Formatting.minutes(fromSeconds: next.seconds)
            if next.kind == .rest {
                content.title = "Toca descansar"
                content.body = "Primer bloque terminado. Tienes \(length) de descanso."
            } else {
                content.title = "Vuelta al estudio"
                content.body = "Empieza el segundo bloque: \(length)."
            }
        } else {
            content.title = "Pomodoro completado"
            content.body = "\(session.plan.title): \(session.plan.focusMinutes) min de estudio. Buen trabajo."
        }
        return content
    }

    // MARK: Scheduled pomodoros

    func scheduleReminder(id: UUID, plan: SessionPlan, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Es la hora de tu pomodoro"
        content.subtitle = plan.title
        content.body = "\(plan.summary). ¿Empezamos?"
        content.sound = .default
        content.categoryIdentifier = NotificationKey.scheduledCategory
        content.userInfo = [NotificationKey.scheduledID: id.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.reminderID(id), content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancelReminder(id: UUID) {
        let identifier = Self.reminderID(id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private static func reminderID(_ id: UUID) -> String {
        "tomate.scheduled.\(id.uuidString)"
    }
}
