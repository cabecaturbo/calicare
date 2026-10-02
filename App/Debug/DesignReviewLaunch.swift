#if DEBUG
import Core
import Foundation
import WidgetKit

/// Debug builds only: lets design-review screenshots pin day or night, and
/// (`-designReviewSeed YES`) start from a known family instead of tapping
/// through onboarding: Cal, onboarded, with last night's two itchy wake-ups.
/// `UNRATED` leaves last night unrated; `EMPTY` adds Cal with nothing logged;
/// `MONTHS` adds about two months of nights and skin answers; `TWO` adds a
/// second child with a long name; `SAMPLE` fills Cal with the eight weeks of
/// sample data from Settings › Debug; `PLAN` adds a draft care plan to review
/// (the example plan's items, as the reader would return them).
enum DesignReviewLaunch {
    static func apply() {
        if DesignReview.applyLaunchArgument() {
            WidgetCenter.shared.reloadAllTimelines()
        }
        if let kind = UserDefaults.standard.string(forKey: "designReviewSeed"), ["YES", "UNRATED", "EMPTY", "MONTHS", "TWO", "SAMPLE", "PLAN"].contains(kind) {
            UserDefaults.standard.set(true, forKey: OnboardingFlag.key)
            Task { await seed(kind) }
        }
    }

    /// What the reader returns for supabase/functions/parse-care-plan/fixtures/example-plan.txt.
    private static let examplePlan: [PlanItemDraft] = [
        PlanItemDraft(kind: .fundamental, text: "Open windows 10 minutes daily", frequency: "daily", sourcePage: 1, sourceLine: "Air: open windows 10 minutes daily. HEPA vacuum 2–3x/week. Keep humidity 40–50%."),
        PlanItemDraft(kind: .fundamental, text: "Hydration: ____ oz water daily", frequency: "daily", sourcePage: 1, sourceLine: "Hydration: ____ oz water daily"),
        PlanItemDraft(kind: .topicalStep, text: "Rinse with lukewarm water", frequency: "3–4x/day", sourcePage: 1, sourceLine: "1. Rinse with lukewarm water"),
        PlanItemDraft(kind: .topicalStep, text: "Apply calendula balm to affected areas", frequency: "3–4x/day", sourcePage: 1, sourceLine: "2. Apply calendula balm to affected areas"),
        PlanItemDraft(kind: .topicalStep, text: "Seal with plain oil", frequency: "3–4x/day", sourcePage: 1, sourceLine: "3. Seal with plain oil"),
        PlanItemDraft(kind: .topicalStep, text: "Patch test any new product on the inner forearm for 24 hours first.", duration: "24 hours", sourcePage: 1, sourceLine: "Patch test any new product on the inner forearm for 24 hours first."),
        PlanItemDraft(kind: .bath, text: "Oat bath", frequency: "3x/week", duration: "10 minutes", sourcePage: 1, sourceLine: "Oat bath 3x/week, 10 minutes"),
        PlanItemDraft(kind: .bath, text: "Rotate baths, don’t combine", sourcePage: 1, sourceLine: "Baths (rotate, don’t combine)"),
        PlanItemDraft(kind: .supplement, text: "Probiotic, Brand A", dose: "1/4 tsp", frequency: "once daily", timing: "with breakfast", duration: "3 months", sourcePage: 2, sourceLine: "Probiotic, Brand A, 1/4 tsp, once daily, with breakfast, 3 months"),
        PlanItemDraft(kind: .supplement, text: "Vitamin D3, Brand B", frequency: "daily", sourcePage: 2, sourceLine: "Vitamin D3, Brand B, dose at next visit, daily"),
        PlanItemDraft(kind: .supplement, text: "Add one at a time, 3–5 days apart", sourcePage: 2, sourceLine: "Add one at a time, 3–5 days apart. Start with a drop."),
        PlanItemDraft(kind: .supplement, text: "Antimicrobial herb, Brand C", dose: "2 drops", frequency: "twice daily", sourcePage: 2, sourceLine: "Antimicrobial herb, Brand C, 2 drops, twice daily, rotate after 3 weeks"),
        PlanItemDraft(kind: .supplement, text: "Start probiotic 2 weeks after antimicrobial", timing: "2 weeks after antimicrobial", sourcePage: 2, sourceLine: "Start probiotic 2 weeks after antimicrobial."),
        PlanItemDraft(kind: .foodRule, text: "Avoid: dairy, eggs, peanuts", sourcePage: 2, sourceLine: "Avoid: dairy, eggs, peanuts"),
        PlanItemDraft(kind: .followUp, text: "Follow-up visit in 4–6 weeks", sourcePage: 2, sourceLine: "Follow-up visit in 4–6 weeks."),
        PlanItemDraft(kind: .followUp, text: "Up to 5 follow-up messages within 8 weeks", sourcePage: 2, sourceLine: "Up to 5 follow-up messages within 8 weeks."),
    ]

    private static func seed(_ kind: String) async {
        guard let container = try? CaliCareModelContainer.shared() else { return }
        let children = ChildStore(modelContainer: container)
        guard (try? await children.activeChildren())?.isEmpty ?? false,
              let cal = try? await children.addChild(name: "Cal", colorTag: "sage")
        else { return }
        CurrentChildSetting().childID = cal.id
        if kind == "PLAN" {
            _ = try? await CarePlanStore(modelContainer: container).createDraft(
                child: cal.id, provider: "Dr. Rivera", items: examplePlan
            )
            return
        }
        if kind == "SAMPLE" {
            _ = try? await SampleData.fill(child: cal.id, container: container)
            await LogChanges.didChange()
            return
        }
        guard kind != "EMPTY" else {
            await LogChanges.didChange()
            return
        }
        let logs = LogStore(modelContainer: container)
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        func at(_ hour: Int, _ minute: Int, daysAgo: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        _ = try? await logs.log(.itchEpisode, child: cal.id, source: .widget, at: at(23, 40, daysAgo: 1))
        _ = try? await logs.log(.itchEpisode, child: cal.id, source: .widget, at: at(1, 52))
        if kind == "TWO" {
            _ = try? await children.addChild(name: "Maximiliana-Josephine", colorTag: "clay")
        }
        if kind == "MONTHS" {
            // A rougher August easing into a calmer September. Some days skipped.
            let nights: [NightRating] = [.rough, .okay, .rough, .okay, .good]
            let skins: [SkinToday] = [.veryRough, .flaring, .littleItchy, .calm]
            for daysAgo in 1...58 where daysAgo % 6 != 0 {
                let calmer = daysAgo < 28
                let night = calmer ? nights[(daysAgo % 3) + 2] : nights[daysAgo % 3]
                let skin = calmer ? skins[(daysAgo % 2) + 2] : skins[daysAgo % 3]
                _ = try? await logs.log(.nightRating, value: .night(night), child: cal.id, source: .notification, at: at(7, 5, daysAgo: daysAgo))
                _ = try? await logs.log(.skinToday, value: .skin(skin), child: cal.id, source: .app, at: at(17, 30, daysAgo: daysAgo))
            }
        }
        if kind == "YES" || kind == "TWO" {
            _ = try? await logs.log(.nightRating, value: .night(.okay), child: cal.id, source: .notification, at: at(7, 5))
        }
        _ = try? await logs.log(.bowelMovement, child: cal.id, source: .app, at: at(9, 10))
        await LogChanges.didChange()
    }
}
#endif
