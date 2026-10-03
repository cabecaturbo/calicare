import Foundation
import SwiftData


/// U2: flare body areas and routine steps. Added fields are optional so the
/// lightweight migration from V1 needs no defaults.
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Child.self, LogEvent.self, RoutineStep.self]
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
        /// Where a flare was: `BodyArea` raw values joined by commas. Nil when not
        /// given. A plain string, not an array: array attributes are stored as
        /// transformables, whose model hash broke the V1 → V2 migration on device.
        public var bodyAreasRaw: String?
        /// The routine step a `routineDone` log ticks off, if it was for one step.
        public var routineStepID: UUID?

        public init(
            id: UUID = UUID(),
            child: Child?,
            type: LogType,
            value: LogValue?,
            note: String?,
            timestamp: Date,
            loggedBy: String,
            entrySource: EntrySource,
            bodyAreas: [BodyArea] = [],
            routineStepID: UUID? = nil,
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
            self.bodyAreasRaw = bodyAreas.isEmpty ? nil : bodyAreas.map(\.rawValue).joined(separator: ",")
            self.routineStepID = routineStepID
        }

        /// Nil only if the stored string is unknown (e.g. written by a newer app version).
        public var type: LogType? { LogType(rawValue: typeRaw) }

        public var value: LogValue? {
            guard let type, let valueRaw else { return nil }
            return LogValue(type: type, raw: valueRaw)
        }

        public var entrySource: EntrySource? { EntrySource(rawValue: entrySourceRaw) }

        /// Every stored area name, including ones from a newer app version (kept for sync).
        public var bodyAreaNames: [String] {
            get { bodyAreasRaw.map { $0.split(separator: ",").map(String.init) } ?? [] }
            set { bodyAreasRaw = newValue.isEmpty ? nil : newValue.joined(separator: ",") }
        }

        /// Known areas only; ones from a newer app version are skipped.
        public var bodyAreas: [BodyArea] { bodyAreaNames.compactMap(BodyArea.init(rawValue:)) }
    }

    /// One step of a child's morning or evening routine, e.g. "Bath" or "Moisturizer".
    @Model
    public final class RoutineStep {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        /// By id rather than a relationship, so sync can apply steps in any order.
        public var childID: UUID
        public var name: String
        public var timeRaw: String
        public var order: Int
        public var isActive: Bool

        public init(
            id: UUID = UUID(),
            childID: UUID,
            name: String,
            time: RoutineTime,
            order: Int,
            isActive: Bool = true,
            now: Date = .now
        ) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.childID = childID
            self.name = name
            self.timeRaw = time.rawValue
            self.order = order
            self.isActive = isActive
        }

        public var time: RoutineTime? { RoutineTime(rawValue: timeRaw) }
    }
}
