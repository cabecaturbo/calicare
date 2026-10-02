import Foundation
import SwiftData

// Current model names always point at the latest schema version.
public typealias Child = SchemaV4.Child
public typealias LogEvent = SchemaV4.LogEvent
public typealias RoutineStep = SchemaV4.RoutineStep
public typealias CarePlan = SchemaV4.CarePlan
public typealias PlanItem = SchemaV4.PlanItem
public typealias Visit = SchemaV4.Visit
public typealias Food = SchemaV4.Food

/// Phase 5: the food list. The V3 models are copied unchanged; Food is new,
/// so the migration from V3 is lightweight.
public enum SchemaV4: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Child.self, LogEvent.self, RoutineStep.self, CarePlan.self, PlanItem.self, Visit.self, Food.self]
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
        /// The care plan item this step came from, when a started plan made it.
        public var planItemID: UUID?

        public init(
            id: UUID = UUID(),
            childID: UUID,
            name: String,
            time: RoutineTime,
            order: Int,
            isActive: Bool = true,
            planItemID: UUID? = nil,
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
            self.planItemID = planItemID
        }

        public var time: RoutineTime? { RoutineTime(rawValue: timeRaw) }
    }

    /// A plan from the child's provider. The original file stays on this phone
    /// (`sourceFileName`, never synced). Nothing is live until it's `active`.
    @Model
    public final class CarePlan {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var childID: UUID
        public var provider: String
        /// The date written on the plan, if any.
        public var planDate: Date?
        /// The original file's name in the app's plans folder, on this phone only.
        public var sourceFileName: String?
        public var statusRaw: String
        public var startedAt: Date?
        public var endedAt: Date?

        public init(id: UUID = UUID(), childID: UUID, provider: String, planDate: Date? = nil,
                    sourceFileName: String? = nil, now: Date = .now) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.childID = childID
            self.provider = provider
            self.planDate = planDate
            self.sourceFileName = sourceFileName
            self.statusRaw = CarePlanStatus.draft.rawValue
        }

        public var status: CarePlanStatus? { CarePlanStatus(rawValue: statusRaw) }
    }

    /// One thing the plan says, as written. Dose, frequency, timing, and
    /// duration are set only when the plan states them; blanks stay nil.
    @Model
    public final class PlanItem {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var planID: UUID
        public var childID: UUID
        public var kindRaw: String
        /// The item in the plan's own words.
        public var text: String
        public var dose: String?
        public var frequency: String?
        public var timing: String?
        public var duration: String?
        /// Where it came from in the original: page number and the exact line.
        public var sourcePage: Int?
        public var sourceLine: String?
        public var isConfirmed: Bool
        public var order: Int

        public init(id: UUID = UUID(), planID: UUID, childID: UUID, kind: PlanItemKind, text: String,
                    dose: String? = nil, frequency: String? = nil, timing: String? = nil, duration: String? = nil,
                    sourcePage: Int? = nil, sourceLine: String? = nil, order: Int, now: Date = .now) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.planID = planID
            self.childID = childID
            self.kindRaw = kind.rawValue
            self.text = text
            self.dose = dose
            self.frequency = frequency
            self.timing = timing
            self.duration = duration
            self.sourcePage = sourcePage
            self.sourceLine = sourceLine
            self.isConfirmed = false
            self.order = order
        }

        public var kind: PlanItemKind? { PlanItemKind(rawValue: kindRaw) }
    }

    /// A visit with a provider: feeds "Since visit" in Progress.
    @Model
    public final class Visit {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var childID: UUID
        public var date: Date
        public var provider: String
        public var notes: String?

        public init(id: UUID = UUID(), childID: UUID, date: Date, provider: String, notes: String? = nil, now: Date = .now) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.childID = childID
            self.date = date
            self.provider = provider
            self.notes = notes
        }
    }

    /// A food on a child's list, with the status the parent (or the plan) set.
    @Model
    public final class Food {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var childID: UUID
        public var name: String
        /// A food family name (for rotation), or nil when not set.
        public var family: String?
        public var statusRaw: String
        public var statusChangedAt: Date
        /// Who decided the status: "plan" or "parent".
        public var decidedByRaw: String
        public var note: String?

        public init(id: UUID = UUID(), childID: UUID, name: String, family: String?, status: FoodStatus,
                    decidedBy: FoodDecider, note: String? = nil, now: Date = .now) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.childID = childID
            self.name = name
            self.family = family
            self.statusRaw = status.rawValue
            self.statusChangedAt = now
            self.decidedByRaw = decidedBy.rawValue
            self.note = note
        }

        public var status: FoodStatus? { FoodStatus(rawValue: statusRaw) }
        public var decidedBy: FoodDecider? { FoodDecider(rawValue: decidedByRaw) }
    }
}
