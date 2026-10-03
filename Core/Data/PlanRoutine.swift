import Foundation

/// Where a plan's daily step goes in Plan's routine, from the plan's own
/// words. Morning or evening when the plan says so; both when it's daily or
/// several times a day, or doesn't say.
public enum PlanRoutine {
    /// Kinds that become routine steps when a plan starts.
    public static let kinds: Set<PlanItemKind> = [.routineStep, .topicalStep]

    private static let morningWords = ["morning", "a.m.", " am", "wake", "breakfast"]
    private static let eveningWords = ["evening", "night", "bed", "p.m.", " pm", "dinner", "after bath"]

    /// Whether an item becomes a daily step: routine and skin steps, except a
    /// patch-test instruction (that's Plan's Patch tests, not a daily step).
    public static func isDailyStep(kind: PlanItemKind, text: String) -> Bool {
        kinds.contains(kind) && !text.localizedCaseInsensitiveContains("patch")
    }

    public static func times(text: String, timing: String?, frequency: String?) -> [RoutineTime] {
        let words = " " + [timing, frequency].compactMap { $0 }.joined(separator: " ").lowercased() + " "
        let saysMorning = morningWords.contains { words.contains($0) }
        let saysEvening = eveningWords.contains { words.contains($0) }
        switch (saysMorning, saysEvening) {
        case (true, false): return [.morning]
        case (false, true): return [.evening]
        default: return [.morning, .evening]
        }
    }
}
