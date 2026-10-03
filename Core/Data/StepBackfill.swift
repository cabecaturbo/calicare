import Foundation
import SwiftData

/// Fills the wording fields added in SchemaV6, once, without changing anything
/// that was there: names, ids, order, plan links, and logs stay as they are.
/// Only empty fields are filled, so running it again changes nothing.
public enum StepBackfill {
    /// Steps whose saved name was cut short and whose full words weren't found
    /// anywhere: the parent re-enters these.
    public struct Result: Equatable, Sendable {
        public var labelled = 0
        public var split = 0
        public var needsReentry: [String] = []
    }

    /// Names were cut to this length before V6.
    static let oldNameLimit = 80

    @discardableResult
    public static func run(in context: ModelContext, now: Date = .now) throws -> Result {
        var result = Result()
        let items = try context.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.deletedAt == nil }))
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        let steps = try context.fetch(FetchDescriptor<RoutineStep>(predicate: #Predicate { $0.deletedAt == nil && $0.sourceText == nil }))
        for step in steps {
            let item = step.planItemID.flatMap { byID[$0] }
            let full = fullText(for: step.name, item: item)
            step.sourceText = full
            if full == step.name, step.name.count == oldNameLimit {
                result.needsReentry.append(step.name)
            }
            var wording = StepLabeler.wording(for: full, planKind: item?.kind, frequency: item?.frequency, duration: item?.duration)
            // The plan reader's checked label wins over the app's own, for tasks.
            if wording.kind == .task, let item, let label = item.label {
                wording.label = label
                wording.detail = item.detail
                wording.category = item.categoryRaw.flatMap(StepCategory.init) ?? wording.category
            }
            apply(wording, to: step)
            step.updatedAt = now
            step.needsSync = true
            result.labelled += 1
        }

        result.split = try splitLists(items: items, in: context, now: now)
        if context.hasChanges { try context.save() }
        return result
    }

    /// Fills a step's empty wording fields.
    static func apply(_ wording: StepWording, to step: RoutineStep) {
        if step.label == nil { step.label = wording.label }
        if step.detail == nil { step.detail = wording.detail }
        if step.categoryRaw == nil { step.categoryRaw = wording.category?.rawValue }
        if step.kindRaw == nil { step.kindRaw = wording.kind.rawValue }
        if step.timesPerDay == nil { step.timesPerDay = wording.timesPerDay }
    }

    /// The step's whole wording: the plan's line when the saved name is a cut-off start of it.
    static func fullText(for name: String, item: PlanItem?) -> String {
        guard let item else { return name }
        for candidate in [item.sourceLine, item.text].compactMap({ $0 })
        where candidate.count > name.count && candidate.hasPrefix(name) {
            return candidate
        }
        return name
    }

    /// "Continue Vitamin C, Cod Liver Oil" in a started plan becomes one new
    /// supplement item per name. The original item stays; the new ones point
    /// to it, carry its line as their source, and are only made once.
    static func splitLists(items: [PlanItem], in context: ModelContext, now: Date) throws -> Int {
        let plans = try context.fetch(FetchDescriptor<CarePlan>(predicate: #Predicate { $0.deletedAt == nil }))
        let started = Set(plans.filter { $0.status != .draft }.map(\.id))
        let parents = Set(try context.fetch(FetchDescriptor<PlanItem>()).compactMap(\.parentItemID))
        var made = 0
        for item in items where item.kind == .supplement && item.parentItemID == nil && started.contains(item.planID)
            && item.isConfirmed && !parents.contains(item.id) {
            let names = SupplementDisplay.listedNames(item.text, dose: item.dose, frequency: item.frequency)
            guard names.count > 1 else { continue }
            for name in names {
                let child = PlanItem(planID: item.planID, childID: item.childID, kind: .supplement, text: name,
                                     sourcePage: item.sourcePage, sourceLine: item.sourceLine ?? item.text,
                                     order: item.order, now: now)
                child.isConfirmed = true
                child.parentItemID = item.id
                child.categoryRaw = StepCategory.give.rawValue
                context.insert(child)
                made += 1
            }
        }
        return made
    }
}

/// Runs the backfill on its own context, at launch and after a plan starts.
public actor StepBackfillRunner: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    @discardableResult
    public func run(now: Date = .now) throws -> StepBackfill.Result {
        try StepBackfill.run(in: modelContext, now: now)
    }
}
