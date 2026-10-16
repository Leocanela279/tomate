import Foundation
import Observation
import SwiftData

/// The local SwiftData store, plus whether the last write made it to disk.
@MainActor
@Observable
final class Persistence {
    let container: ModelContainer

    /// True when the last save failed, for example because the disk is full.
    private(set) var lastSaveFailed = false

    var context: ModelContext { container.mainContext }

    init() {
        do {
            if DemoData.isActive {
                // Sample data in memory only: the real store is not opened.
                let demo = try ModelContainer(for: FocusRecord.self, ScheduledPomodoro.self,
                                              configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                DemoData.seed(demo.mainContext)
                container = demo
                return
            }
            container = try ModelContainer(for: FocusRecord.self, ScheduledPomodoro.self,
                                           configurations: ModelConfiguration("Tomate"))
        } catch {
            fatalError("No se pudo abrir el almacenamiento local de Tomate: \(error)")
        }
    }

    /// Saves pending changes. On failure they are rolled back so the screen
    /// never shows something that is not really stored.
    @discardableResult
    func save() -> Bool {
        do {
            try context.save()
            lastSaveFailed = false
            return true
        } catch {
            print("Tomate: no se pudo guardar: \(error)")
            context.rollback()
            lastSaveFailed = true
            return false
        }
    }
}
