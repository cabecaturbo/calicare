import Core
import Foundation
import Testing

/// Plan's "Evening · 2 left": steps ticked off today, or the routine logged in one tap.
struct RoutineProgressTests {
    private let child = UUID()

    private func step(_ name: String, _ time: RoutineTime, _ order: Int, active: Bool = true) -> RoutineStepInfo {
        RoutineStepInfo(id: UUID(), childID: child, name: name, time: time, order: order, isActive: active)
    }

    private func done(_ time: RoutineTime, step: RoutineStepInfo? = nil, at hour: Int) -> LogEntry {
        LogEntry(childID: child, type: .routineDone, value: .routine(time), timestamp: TestTime.date(26, hour), routineStepID: step?.id)
    }

    @Test func countsWhatsLeftInOrder() {
        let bath = step("Bath", .evening, 0)
        let cream = step("Cream", .evening, 1)
        let paused = step("Wraps", .evening, 2, active: false)
        let wash = step("Wash", .morning, 0)
        let steps = [cream, wash, paused, bath]

        let none = RoutineProgress(time: .evening, steps: steps, entries: [])
        #expect(none.steps.map(\.name) == ["Bath", "Cream"])
        #expect(none.title == "Evening · 2 steps")
        #expect(!none.isDone)

        let one = RoutineProgress(time: .evening, steps: steps, entries: [done(.evening, step: bath, at: 19)])
        #expect(one.left == 1)
        #expect(one.title == "Evening · 1 left")

        let all = RoutineProgress(time: .evening, steps: steps, entries: [done(.evening, step: bath, at: 19), done(.evening, step: cream, at: 20)])
        #expect(all.isDone)
        #expect(all.title == "Evening · done")
        #expect(all.finishedAt == TestTime.date(26, 20))
    }

    @Test func withoutStepsOneTapIsTheRoutine() {
        let before = RoutineProgress(time: .morning, steps: [], entries: [done(.evening, at: 20)])
        #expect(before.title == "Morning · not done yet")
        let after = RoutineProgress(time: .morning, steps: [], entries: [done(.morning, at: 8)])
        #expect(after.isDone)
        #expect(after.finishedAt == TestTime.date(26, 8))
    }

    @Test func aOneTapLogDoesNotTickSteps() {
        let bath = step("Bath", .evening, 0)
        let progress = RoutineProgress(time: .evening, steps: [bath], entries: [done(.evening, at: 20)])
        #expect(progress.left == 1)
        #expect(progress.wholeRoutineLog != nil)
        #expect(progress.title == "Evening · 1 step")
    }
}
