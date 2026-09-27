import Foundation
import SwiftData

/// Everything this phone keeps about children and logs.
public enum LocalData {
    /// Erases all children and logs from this phone, and forgets the current
    /// child. Only when someone asks for it, e.g. "Delete data on this phone"
    /// while deleting their account.
    public static func eraseAll(
        container: ModelContainer,
        currentChild: CurrentChildSetting = CurrentChildSetting()
    ) throws {
        // One by one, logs first: a bulk delete can't unlink logs from children.
        let context = ModelContext(container)
        for event in try context.fetch(FetchDescriptor<LogEvent>()) { context.delete(event) }
        for child in try context.fetch(FetchDescriptor<Child>()) { context.delete(child) }
        try context.save()
        currentChild.childID = nil
    }
}
