import Foundation
import SwiftData

/// What one sync did.
public struct SyncReport: Equatable, Sendable {
    public var pushedChildren = 0
    public var pushedLogs = 0
    public var pushedRoutineSteps = 0
    /// Rows from the server that changed something on this phone.
    public var appliedChildren = 0
    public var appliedLogs = 0
    public var appliedRoutineSteps = 0

    public init() {}

    public var changedLocalData: Bool { appliedChildren + appliedLogs + appliedRoutineSteps > 0 }
}

/// Keeps this phone and the household's server copy in step.
///
/// Push: rows with needsSync go up (upsert by id), then the flag clears.
/// Pull: rows changed on the server since the cursor come down and merge.
/// Conflicts: last write wins by updatedAt, here and on the server.
/// Deletes are soft (deletedAt) and sync like any edit.
/// Only the app runs this; widgets and intents just set needsSync.
public actor SyncEngine: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let remote: any SyncRemote
    private let settings: SyncSettings
    private let now: @Sendable () -> Date

    /// Pull a little before the cursor, in case a write committed late with an
    /// earlier server time. Merging is idempotent, so the overlap is harmless.
    static let cursorOverlap: TimeInterval = 5
    static let batchSize = 500

    public init(
        modelContainer: ModelContainer,
        remote: any SyncRemote,
        settings: SyncSettings = SyncSettings(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.remote = remote
        self.settings = settings
        self.now = now
    }

    /// One full round: find or make the household, push, then pull.
    @discardableResult
    public func sync(userID: UUID, displayName: String) async throws -> SyncReport {
        let household = try await household(for: userID, displayName: displayName)
        var report = SyncReport()
        try await push(to: household, report: &report)
        try await pull(from: household, report: &report)
        settings.householdSize = try await remote.memberCount(household: household)
        settings.lastSyncedAt = now()
        return report
    }

    // MARK: - Household

    /// The first time an account syncs on this phone, it joins its household
    /// (making one if needed), and everything already on the phone is queued
    /// to upload into it.
    private func household(for userID: UUID, displayName: String) async throws -> UUID {
        if settings.userID == userID, let known = settings.householdID { return known }

        let household: UUID
        if let existing = try await remote.householdID() {
            household = existing
        } else {
            household = UUID()
            try await remote.createHousehold(id: household, name: "", memberID: UUID(), displayName: displayName)
        }
        try markEverythingForUpload(claimingAs: displayName)
        settings.userID = userID
        settings.householdID = household
        settings.cursor = nil
        return household
    }

    /// Switches this phone to another household after accepting an invite.
    /// Everything already on the phone is queued to upload into it.
    public func join(household: UUID, userID: UUID, displayName: String) throws {
        try markEverythingForUpload(claimingAs: displayName)
        settings.userID = userID
        settings.householdID = household
        settings.cursor = nil
    }

    /// Children and logs on this phone (not deleted), to ask before merging them into a household.
    public func localRecordCount() throws -> (children: Int, logs: Int) {
        let children = try modelContext.fetchCount(FetchDescriptor<Child>(predicate: #Predicate { $0.deletedAt == nil }))
        let logs = try modelContext.fetchCount(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.deletedAt == nil }))
        return (children, logs)
    }

    /// Queues everything to upload. Logs made before signing in ("You") take
    /// the person's name, so other phones never show them as "by you".
    private func markEverythingForUpload(claimingAs displayName: String) throws {
        for child in try modelContext.fetch(FetchDescriptor<Child>()) { child.needsSync = true }
        for step in try modelContext.fetch(FetchDescriptor<RoutineStep>()) { step.needsSync = true }
        for event in try modelContext.fetch(FetchDescriptor<LogEvent>()) {
            if LoggedBy.legacyNames.contains(event.loggedBy) {
                event.loggedBy = displayName
                event.updatedAt = max(event.updatedAt, now())
            }
            event.needsSync = true
        }
        try modelContext.save()
    }

    // MARK: - Push

    private func push(to household: UUID, report: inout SyncReport) async throws {
        // Children first: routine steps and logs point at them.
        let children = try modelContext.fetch(FetchDescriptor<Child>(predicate: #Predicate { $0.needsSync }))
        for batch in children.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(children: batch.map { RemoteChild($0, household: household) })
            try clearFlags(Child.self, sent)
            report.pushedChildren += batch.count
        }

        let steps = try modelContext.fetch(FetchDescriptor<RoutineStep>(predicate: #Predicate { $0.needsSync }))
        for batch in steps.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(routineSteps: batch.map { RemoteRoutineStep($0, household: household) })
            try clearFlags(RoutineStep.self, sent)
            report.pushedRoutineSteps += batch.count
        }

        let logs = try modelContext.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.needsSync }))
        for batch in logs.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(logs: batch.map { RemoteLogEvent($0, household: household) })
            try clearFlags(LogEvent.self, sent)
            report.pushedLogs += batch.count
        }
    }

    /// Clears needsSync only if the row wasn't edited again while uploading.
    private func clearFlags<Model: SyncedModel>(_ type: Model.Type, _ sent: [(id: UUID, updatedAt: Date)]) throws {
        let versions = Dictionary(sent.map { ($0.id, $0.updatedAt) }, uniquingKeysWith: { a, _ in a })
        let ids = Array(versions.keys)
        for row in try modelContext.fetch(Model.descriptor(ids: ids)) where row.updatedAt == versions[row.id] {
            row.needsSync = false
        }
        try modelContext.save()
    }

    // MARK: - Pull

    private func pull(from household: UUID, report: inout SyncReport) async throws {
        let since = settings.cursor.map { $0.addingTimeInterval(-Self.cursorOverlap) }
        let changes = try await remote.changes(household: household, since: since)

        for remoteChild in changes.children {
            if try merge(remoteChild) { report.appliedChildren += 1 }
        }
        for remoteStep in changes.routineSteps {
            if try merge(remoteStep) { report.appliedRoutineSteps += 1 }
        }
        for remoteLog in changes.logs {
            if try merge(remoteLog) { report.appliedLogs += 1 }
        }
        try modelContext.save()
        if let latest = changes.latestServerTime, latest > (settings.cursor ?? .distantPast) {
            settings.cursor = latest
        }
    }

    /// Applies a server row if it's newer than this phone's copy. Returns true if anything changed.
    private func merge(_ remote: RemoteChild) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<Child>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let child = local ?? {
            let new = Child(id: remote.id, name: remote.name, colorTag: remote.colorTag)
            modelContext.insert(new)
            return new
        }()
        child.name = remote.name
        child.birthDate = remote.birthDate
        child.colorTag = remote.colorTag
        child.isActive = remote.isActive
        child.createdAt = remote.createdAt
        child.updatedAt = remote.updatedAt
        child.deletedAt = remote.deletedAt
        child.needsSync = false
        return true
    }

    private func merge(_ remote: RemoteLogEvent) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let childID = remote.childID
        let child = try childID.flatMap { id in
            try modelContext.fetch(FetchDescriptor<Child>(predicate: #Predicate { $0.id == id })).first
        }
        let event = local ?? {
            let new = LogEvent(
                id: remote.id, child: child, type: .note, value: nil, note: nil,
                timestamp: remote.occurredAt, loggedBy: remote.loggedBy, entrySource: .app
            )
            modelContext.insert(new)
            return new
        }()
        event.child = child
        event.typeRaw = remote.type
        event.valueRaw = remote.value
        event.note = remote.note
        event.timestamp = remote.occurredAt
        event.loggedBy = remote.loggedBy
        event.entrySourceRaw = remote.entrySource
        event.bodyAreaNames = remote.bodyAreas
        event.routineStepID = remote.routineStepID
        event.createdAt = remote.createdAt
        event.updatedAt = remote.updatedAt
        event.deletedAt = remote.deletedAt
        event.needsSync = false
        return true
    }

    private func merge(_ remote: RemoteRoutineStep) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<RoutineStep>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let step = local ?? {
            let new = RoutineStep(id: remote.id, childID: remote.childID, name: remote.name, time: .morning, order: remote.sortOrder)
            modelContext.insert(new)
            return new
        }()
        step.childID = remote.childID
        step.name = remote.name
        // Raw, so a time from a newer app version passes through untouched.
        step.timeRaw = remote.time
        step.order = remote.sortOrder
        step.isActive = remote.isActive
        step.createdAt = remote.createdAt
        step.updatedAt = remote.updatedAt
        step.deletedAt = remote.deletedAt
        step.needsSync = false
        return true
    }
}

// MARK: - Mapping

extension RemoteChild {
    init(_ child: Child, household: UUID) {
        self.init(
            id: child.id, householdID: household, name: child.name, birthDate: child.birthDate,
            colorTag: child.colorTag, isActive: child.isActive,
            createdAt: child.createdAt, updatedAt: child.updatedAt, deletedAt: child.deletedAt
        )
    }
}

extension RemoteLogEvent {
    init(_ event: LogEvent, household: UUID) {
        self.init(
            id: event.id, householdID: household, childID: event.child?.id,
            type: event.typeRaw, value: event.valueRaw, note: event.note,
            occurredAt: event.timestamp, loggedBy: event.loggedBy, entrySource: event.entrySourceRaw,
            bodyAreas: event.bodyAreaNames, routineStepID: event.routineStepID,
            createdAt: event.createdAt, updatedAt: event.updatedAt, deletedAt: event.deletedAt
        )
    }
}

extension RemoteRoutineStep {
    init(_ step: RoutineStep, household: UUID) {
        self.init(
            id: step.id, householdID: household, childID: step.childID, name: step.name,
            time: step.timeRaw, sortOrder: step.order, isActive: step.isActive,
            createdAt: step.createdAt, updatedAt: step.updatedAt, deletedAt: step.deletedAt
        )
    }
}

/// The shared shape of synced models, for clearing flags generically.
protocol SyncedModel: PersistentModel {
    var id: UUID { get }
    var updatedAt: Date { get }
    var needsSync: Bool { get set }
    static func descriptor(ids: [UUID]) -> FetchDescriptor<Self>
}

extension Child: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<Child> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension LogEvent: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<LogEvent> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension RoutineStep: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<RoutineStep> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
