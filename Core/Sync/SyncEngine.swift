import Foundation
import SwiftData

/// What one sync did.
public struct SyncReport: Equatable, Sendable {
    public var pushedChildren = 0
    public var pushedLogs = 0
    public var pushedRoutineSteps = 0
    public var pushedPlans = 0
    public var pushedPlanItems = 0
    public var pushedVisits = 0
    public var pushedFoods = 0
    public var pushedProducts = 0
    /// Rows from the server that changed something on this phone.
    public var appliedChildren = 0
    public var appliedLogs = 0
    public var appliedRoutineSteps = 0
    public var appliedPlans = 0
    public var appliedPlanItems = 0
    public var appliedVisits = 0
    public var appliedFoods = 0
    public var appliedProducts = 0

    public init() {}

    public var changedLocalData: Bool {
        appliedChildren + appliedLogs + appliedRoutineSteps + appliedPlans + appliedPlanItems + appliedVisits + appliedFoods
            + appliedProducts > 0
    }
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
        for plan in try modelContext.fetch(FetchDescriptor<CarePlan>()) { plan.needsSync = true }
        for item in try modelContext.fetch(FetchDescriptor<PlanItem>()) { item.needsSync = true }
        for visit in try modelContext.fetch(FetchDescriptor<Visit>()) { visit.needsSync = true }
        for food in try modelContext.fetch(FetchDescriptor<Food>()) { food.needsSync = true }
        for product in try modelContext.fetch(FetchDescriptor<Product>()) { product.needsSync = true }
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

        try await pushCarePlans(to: household, report: &report)

        let visits = try modelContext.fetch(FetchDescriptor<Visit>(predicate: #Predicate { $0.needsSync }))
        for batch in visits.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(visits: batch.map { RemoteVisit($0, household: household) })
            try clearFlags(Visit.self, sent)
            report.pushedVisits += batch.count
        }

        let foods = try modelContext.fetch(FetchDescriptor<Food>(predicate: #Predicate { $0.needsSync }))
        for batch in foods.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(foods: batch.map { RemoteFood($0, household: household) })
            try clearFlags(Food.self, sent)
            report.pushedFoods += batch.count
        }

        let products = try modelContext.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.needsSync }))
        for batch in products.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(products: batch.map { RemoteProduct($0, household: household) })
            try clearFlags(Product.self, sent)
            report.pushedProducts += batch.count
        }
    }

    /// Only what the parent confirmed goes up: started or ended plans, and
    /// their confirmed items. Drafts wait on the phone (flag kept, so they go
    /// up once started). Anything that will never go up has its flag cleared.
    private func pushCarePlans(to household: UUID, report: inout SyncReport) async throws {
        let draft = CarePlanStatus.draft.rawValue
        let plans = try modelContext.fetch(FetchDescriptor<CarePlan>(predicate: #Predicate { $0.needsSync }))
        let (drafts, started) = (plans.filter { $0.statusRaw == draft }, plans.filter { $0.statusRaw != draft })
        for plan in drafts where plan.deletedAt != nil { plan.needsSync = false }
        for batch in started.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(carePlans: batch.map { RemoteCarePlan($0, household: household) })
            try clearFlags(CarePlan.self, sent)
            report.pushedPlans += batch.count
        }

        let items = try modelContext.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.needsSync }))
        let planIDs = Array(Set(items.map(\.planID)))
        let statuses = Dictionary(
            try modelContext.fetch(FetchDescriptor<CarePlan>(predicate: #Predicate { planIDs.contains($0.id) }))
                .map { ($0.id, $0.statusRaw) },
            uniquingKeysWith: { a, _ in a }
        )
        var ready: [PlanItem] = []
        for item in items {
            let status = statuses[item.planID]
            if status == nil || status == draft {
                // Still being reviewed: wait, unless it's already gone.
                if item.deletedAt != nil { item.needsSync = false }
            } else if item.isConfirmed {
                ready.append(item)
            } else {
                item.needsSync = false // never confirmed, never uploaded
            }
        }
        try modelContext.save()
        for batch in ready.chunked(Self.batchSize) {
            let sent = batch.map { (id: $0.id, updatedAt: $0.updatedAt) }
            try await remote.upsert(planItems: batch.map { RemotePlanItem($0, household: household) })
            try clearFlags(PlanItem.self, sent)
            report.pushedPlanItems += batch.count
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
        for remotePlan in changes.carePlans {
            if try merge(remotePlan) { report.appliedPlans += 1 }
        }
        for remoteItem in changes.planItems {
            if try merge(remoteItem) { report.appliedPlanItems += 1 }
        }
        for remoteVisit in changes.visits {
            if try merge(remoteVisit) { report.appliedVisits += 1 }
        }
        for remoteFood in changes.foods {
            if try merge(remoteFood) { report.appliedFoods += 1 }
        }
        for remoteProduct in changes.products {
            if try merge(remoteProduct) { report.appliedProducts += 1 }
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
        step.planItemID = remote.planItemID
        step.label = remote.label
        step.detail = remote.detail
        step.sourceText = remote.sourceText
        step.categoryRaw = remote.category
        step.timesPerDay = remote.timesPerDay
        step.kindRaw = remote.kind
        step.createdAt = remote.createdAt
        step.updatedAt = remote.updatedAt
        step.deletedAt = remote.deletedAt
        step.needsSync = false
        return true
    }
}

extension SyncEngine {
    private func merge(_ remote: RemoteCarePlan) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<CarePlan>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let plan = local ?? {
            let new = CarePlan(id: remote.id, childID: remote.childID, provider: remote.provider)
            modelContext.insert(new)
            return new
        }()
        // sourceFileName stays whatever this phone has: the file never syncs.
        plan.childID = remote.childID
        plan.provider = remote.provider
        plan.planDate = remote.planDate
        plan.statusRaw = remote.status
        plan.startedAt = remote.startedAt
        plan.endedAt = remote.endedAt
        plan.lengthWeeks = remote.lengthWeeks
        plan.createdAt = remote.createdAt
        plan.updatedAt = remote.updatedAt
        plan.deletedAt = remote.deletedAt
        plan.needsSync = false
        return true
    }

    private func merge(_ remote: RemotePlanItem) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let item = local ?? {
            let new = PlanItem(id: remote.id, planID: remote.planID, childID: remote.childID, kind: .fundamental,
                               text: remote.text, order: remote.sortOrder)
            modelContext.insert(new)
            return new
        }()
        item.planID = remote.planID
        item.childID = remote.childID
        // Raw, so a kind from a newer app version passes through untouched.
        item.kindRaw = remote.kind
        item.text = remote.text
        item.dose = remote.dose
        item.frequency = remote.frequency
        item.timing = remote.timing
        item.duration = remote.duration
        item.sourcePage = remote.sourcePage
        item.sourceLine = remote.sourceLine
        item.label = remote.label
        item.detail = remote.detail
        item.categoryRaw = remote.category
        item.parentItemID = remote.parentItemID
        item.isGiving = remote.isGiving
        item.givingTimesRaw = remote.givingTimes
        item.plainText = remote.plainText
        item.sourceParagraph = remote.sourceParagraph
        item.doseStepsRaw = remote.doseSteps
        item.order = remote.sortOrder
        item.isConfirmed = true
        item.createdAt = remote.createdAt
        item.updatedAt = remote.updatedAt
        item.deletedAt = remote.deletedAt
        item.needsSync = false
        return true
    }

    private func merge(_ remote: RemoteVisit) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<Visit>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let visit = local ?? {
            let new = Visit(id: remote.id, childID: remote.childID, date: remote.date, provider: remote.provider)
            modelContext.insert(new)
            return new
        }()
        visit.childID = remote.childID
        visit.date = remote.date
        visit.provider = remote.provider
        visit.notes = remote.notes
        visit.createdAt = remote.createdAt
        visit.updatedAt = remote.updatedAt
        visit.deletedAt = remote.deletedAt
        visit.needsSync = false
        return true
    }
}

extension SyncEngine {
    private func merge(_ remote: RemoteFood) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<Food>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let food = local ?? {
            let new = Food(id: remote.id, childID: remote.childID, name: remote.name, family: nil, status: .safe, decidedBy: .parent)
            modelContext.insert(new)
            return new
        }()
        food.childID = remote.childID
        food.name = remote.name
        food.family = remote.family
        food.statusRaw = remote.status
        food.statusChangedAt = remote.statusChangedAt
        food.decidedByRaw = remote.decidedBy
        food.note = remote.note
        food.createdAt = remote.createdAt
        food.updatedAt = remote.updatedAt
        food.deletedAt = remote.deletedAt
        food.needsSync = false
        return true
    }
}

extension RemoteFood {
    init(_ food: Food, household: UUID) {
        self.init(
            id: food.id, householdID: household, childID: food.childID, name: food.name, family: food.family,
            status: food.statusRaw, statusChangedAt: food.statusChangedAt, decidedBy: food.decidedByRaw, note: food.note,
            createdAt: food.createdAt, updatedAt: food.updatedAt, deletedAt: food.deletedAt
        )
    }
}

extension SyncEngine {
    private func merge(_ remote: RemoteProduct) throws -> Bool {
        let id = remote.id
        let local = try modelContext.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.id == id })).first
        if let local, local.updatedAt >= remote.updatedAt { return false }
        let product = local ?? {
            let new = Product(id: remote.id, childID: remote.childID, name: remote.name, category: .other, startedAt: remote.startedAt)
            modelContext.insert(new)
            return new
        }()
        product.childID = remote.childID
        product.name = remote.name
        product.categoryRaw = remote.category
        product.startedAt = remote.startedAt
        product.stoppedAt = remote.stoppedAt
        product.neverAgain = remote.neverAgain
        product.reason = remote.reason
        product.restockEveryDays = remote.restockEveryDays
        product.restockedAt = remote.restockedAt
        product.createdAt = remote.createdAt
        product.updatedAt = remote.updatedAt
        product.deletedAt = remote.deletedAt
        product.needsSync = false
        return true
    }
}

extension RemoteProduct {
    init(_ product: Product, household: UUID) {
        self.init(
            id: product.id, householdID: household, childID: product.childID, name: product.name,
            category: product.categoryRaw, startedAt: product.startedAt, stoppedAt: product.stoppedAt,
            neverAgain: product.neverAgain, reason: product.reason, restockEveryDays: product.restockEveryDays,
            restockedAt: product.restockedAt, createdAt: product.createdAt, updatedAt: product.updatedAt,
            deletedAt: product.deletedAt
        )
    }
}

// MARK: - Mapping

extension RemoteCarePlan {
    init(_ plan: CarePlan, household: UUID) {
        self.init(
            id: plan.id, householdID: household, childID: plan.childID, provider: plan.provider,
            planDate: plan.planDate, status: plan.statusRaw, startedAt: plan.startedAt, endedAt: plan.endedAt,
            createdAt: plan.createdAt, updatedAt: plan.updatedAt, deletedAt: plan.deletedAt
        )
        lengthWeeks = plan.lengthWeeks
    }
}

extension RemotePlanItem {
    init(_ item: PlanItem, household: UUID) {
        self.init(
            id: item.id, householdID: household, planID: item.planID, childID: item.childID, kind: item.kindRaw,
            text: item.text, dose: item.dose, frequency: item.frequency, timing: item.timing, duration: item.duration,
            sourcePage: item.sourcePage, sourceLine: item.sourceLine, sortOrder: item.order,
            createdAt: item.createdAt, updatedAt: item.updatedAt, deletedAt: item.deletedAt
        )
        label = item.label
        detail = item.detail
        category = item.categoryRaw
        parentItemID = item.parentItemID
        isGiving = item.isGiving
        givingTimes = item.givingTimesRaw
        plainText = item.plainText
        sourceParagraph = item.sourceParagraph
        doseSteps = item.doseStepsRaw
    }
}

extension RemoteVisit {
    init(_ visit: Visit, household: UUID) {
        self.init(
            id: visit.id, householdID: household, childID: visit.childID, date: visit.date, provider: visit.provider,
            notes: visit.notes, createdAt: visit.createdAt, updatedAt: visit.updatedAt, deletedAt: visit.deletedAt
        )
    }
}

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
            time: step.timeRaw, sortOrder: step.order, isActive: step.isActive, planItemID: step.planItemID,
            createdAt: step.createdAt, updatedAt: step.updatedAt, deletedAt: step.deletedAt
        )
        label = step.label
        detail = step.detail
        sourceText = step.sourceText
        category = step.categoryRaw
        timesPerDay = step.timesPerDay
        kind = step.kindRaw
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

extension CarePlan: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<CarePlan> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension PlanItem: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<PlanItem> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension Visit: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<Visit> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension Food: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<Food> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension Product: SyncedModel {
    static func descriptor(ids: [UUID]) -> FetchDescriptor<Product> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
