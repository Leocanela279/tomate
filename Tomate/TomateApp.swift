import SwiftUI

@main
struct TomateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let model = appDelegate.model

        Window("Tomate", id: AppModel.mainWindowID) {
            MainView()
                .environment(model)
                .environment(model.engine)
                .modelContainer(model.container)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 920, height: 680)

        // The small window in the menu bar: remaining time at a glance, even with the main window closed.
        MenuBarExtra {
            MenuBarPanel()
                .environment(model)
                .environment(model.engine)
                .modelContainer(model.container)
        } label: {
            MenuBarLabel(engine: model.engine)
        }
        .menuBarExtraStyle(.window)

        // Tomate ▸ Ajustes… (⌘,)
        Settings {
            SettingsView()
                .environment(model)
        }
        .windowResizability(.contentSize)
    }
}
