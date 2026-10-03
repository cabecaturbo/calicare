import Core
import Foundation

/// Once per launch, for each child's running plan: brings back any provider
/// line that was cut short (from the saved original), and fills plain words
/// for lines that don't have them yet. Never changes the provider's words.
enum PlanUpkeep {
    /// Kinds whose "What to do" a parent reads.
    static let plainKinds: Set<PlanItemKind> = [.routineStep, .topicalStep, .supplement, .medication, .bath]

    static func run() async {
        guard let container = try? CaliCareModelContainer.shared(),
              let children = try? await ChildStore(modelContainer: container).activeChildren()
        else { return }
        let plans = CarePlanStore(modelContainer: container)
        var changed = false
        for child in children {
            guard let plan = try? await plans.activePlan(child: child.id),
                  let items = try? await plans.items(plan: plan.id)
            else { continue }
            changed = await restoreParagraphs(plan: plan, items: items, store: plans) || changed
            changed = await fillPlainWords(items: (try? await plans.items(plan: plan.id)) ?? items, store: plans) || changed
        }
        if changed { await LogChanges.didChange() }
    }

    /// From the original file on this phone: the whole paragraph for lines cut short.
    private static func restoreParagraphs(plan: CarePlanInfo, items: [PlanItemInfo], store: CarePlanStore) async -> Bool {
        let key = "planUpkeep.paragraphs.\(plan.id.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key),
              let name = plan.sourceFileName,
              FileManager.default.fileExists(atPath: PlanFiles.url(for: name).path),
              let text = try? await PlanTextExtractor.text(fromPDF: PlanFiles.url(for: name))
        else { return false }
        let lines = items.compactMap(\.sourceLine)
        var changed = false
        for item in items where item.sourceParagraph == nil {
            guard let line = item.sourceLine,
                  let paragraph = SourceParagraph.find(line, in: text, otherLines: lines)
            else { continue }
            try? await store.setSourceParagraph(item.id, paragraph)
            changed = true
        }
        UserDefaults.standard.set(true, forKey: key)
        return changed
    }

    /// Asks once a day for lines still without plain words (needs sign-in).
    private static func fillPlainWords(items: [PlanItemInfo], store: CarePlanStore) async -> Bool {
        let missing = items.filter {
            plainKinds.contains($0.kind) && $0.plainText == nil && !SupplementDisplay.isMention($0.text)
                && ($0.kind != .supplement || $0.timing != nil || $0.duration != nil)
        }
        let day = Calendar.autoupdatingCurrent.startOfDay(for: .now).timeIntervalSince1970
        let key = "planUpkeep.plainAsked"
        guard !missing.isEmpty, UserDefaults.standard.double(forKey: key) != day else { return false }
        UserDefaults.standard.set(day, forKey: key)
        guard let plain = try? await PlanReader.plainWords(missing.prefix(60).map { ($0.id, $0.providerWords) }) else { return false }
        var changed = false
        for (id, words) in plain {
            changed = ((try? await store.setPlainText(id, words)) ?? false) || changed
        }
        return changed
    }
}
