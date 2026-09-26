import Core
import Foundation
import Testing

struct NightModeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: hour, minute: minute))!
    }

    @Test(arguments: [20, 23, 0, 2, 6])
    func activeAtNight(hour: Int) {
        #expect(NightMode.isActive(at: date(hour: hour), calendar: calendar))
    }

    @Test(arguments: [7, 12, 19])
    func inactiveDuringDay(hour: Int) {
        #expect(!NightMode.isActive(at: date(hour: hour), calendar: calendar))
    }

    @Test func edgesAreExact() {
        #expect(!NightMode.isActive(at: date(hour: 19, minute: 59), calendar: calendar))
        #expect(NightMode.isActive(at: date(hour: 6, minute: 59), calendar: calendar))
    }

    @Test func nextChangeDuringDayIsEightPM() {
        let next = NightMode.nextChange(after: date(hour: 13, minute: 15), calendar: calendar)
        #expect(next == date(hour: 20))
    }

    @Test func nextChangeAtNightIsSevenAMNextDay() {
        let next = NightMode.nextChange(after: date(hour: 22), calendar: calendar)
        let expected = calendar.date(byAdding: .day, value: 1, to: date(hour: 7))!
        #expect(next == expected)
    }

    @Test func paletteFollowsNightMode() {
        #expect(Palette.current(at: date(hour: 21), calendar: calendar) == .night)
        #expect(Palette.current(at: date(hour: 9), calendar: calendar) == .day)
    }
}
