import Foundation

/// A read-only copy of a log, safe to pass between actors and processes.
public struct LogEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID?
    public let type: LogType
    public let value: LogValue?
    public let note: String?
    public let timestamp: Date
    public let loggedBy: String
    public let source: EntrySource

    public init(
        id: UUID = UUID(),
        childID: UUID?,
        type: LogType,
        value: LogValue? = nil,
        note: String? = nil,
        timestamp: Date,
        loggedBy: String = "",
        source: EntrySource = .app
    ) {
        self.id = id
        self.childID = childID
        self.type = type
        self.value = value
        self.note = note
        self.timestamp = timestamp
        self.loggedBy = loggedBy
        self.source = source
    }
}

/// A read-only copy of a child.
public struct ChildInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let birthDate: Date?
    public let colorTag: String
    public let isActive: Bool
}

extension LogEntry {
    /// Nil for rows with an unknown type or source (written by a newer app version).
    init?(_ event: LogEvent) {
        guard let type = event.type, let source = event.entrySource else { return nil }
        self.init(
            id: event.id,
            childID: event.child?.id,
            type: type,
            value: event.value,
            note: event.note,
            timestamp: event.timestamp,
            loggedBy: event.loggedBy,
            source: source
        )
    }
}

extension ChildInfo {
    init(_ child: Child) {
        self.init(
            id: child.id,
            name: child.name,
            birthDate: child.birthDate,
            colorTag: child.colorTag,
            isActive: child.isActive
        )
    }
}
