import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = AppModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set before launch finishes so a notification that opened the app is still delivered here.
        UNUserNotificationCenter.current().delegate = self
        model.notifier.registerCategories()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await self.model.bootstrap() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // The user may have changed notification permissions in System Settings.
        Task { await self.model.notifier.refreshStatus() }
    }

    /// Closing the window keeps Tomate alive in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { model.presentMainWindow() }
        return true
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let rawID = response.notification.request.content.userInfo[NotificationKey.scheduledID] as? String
        await MainActor.run {
            self.model.handleNotification(action: action, scheduledID: rawID.flatMap(UUID.init(uuidString:)))
        }
    }
}
