import Foundation
import SwiftData

// Current model names always point at the latest schema version.
public typealias Child = SchemaV1.Child
public typealias LogEvent = SchemaV1.LogEvent

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Child.self, LogEvent.self]
    }

    @Model
    public final class Child {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var name: String
        public var birthDate: Date?
        public var colorTag: String
        public var isActive: Bool

        @Relationship(deleteRule: .nullify, inverse: \LogEvent.child)
        public var events: [LogEvent] = []

        public init(
            id: UUID = UUID(),
            name: String,
            birthDate: Date? = nil,
            colorTag: String,
            isActive: Bool = true,
            now: Date = .now
        ) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.name = name
            self.birthDate = birthDate
            self.colorTag = colorTag
            self.isActive = isActive
        }
    }

    @Model
    public final class LogEvent {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var child: Child?
        /// Stored as raw strings so predicates and migrations stay simple.
        public var typeRaw: String
        public var valueRaw: String?
        public var note: String?
        public var timestamp: Date
        public var loggedBy: String
        public var entrySourceRaw: String

        public init(
            id: UUID = UUID(),
            child: Child?,
            type: LogType,
            value: LogValue?,
            note: String?,
            timestamp: Date,
            loggedBy: String,
            entrySource: EntrySource,
            now: Date = .now
        ) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.child = child
            self.typeRaw = type.rawValue
            self.valueRaw = value?.rawValue
            self.note = note
            self.timestamp = timestamp
            self.loggedBy = loggedBy
            self.entrySourceRaw = entrySource.rawValue
        }

        /// Nil only if the stored string is unknown (e.g. written by a newer app version).
        public var type: LogType? { LogType(rawValue: typeRaw) }

        public var value: LogValue? {
            guard let type, let valueRaw else { return nil }
            return LogValue(type: type, raw: valueRaw)
        }

        public var entrySource: EntrySource? { EntrySource(rawValue: entrySourceRaw) }
    }
}
