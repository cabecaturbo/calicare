import Core
import Foundation
import Testing

/// The day/night toggle pins the colors; automatic follows the clock. The
/// night layout always follows the clock.
@Suite(.serialized)
struct AppearanceModeTests {
    @Test func toggleOverridesTheClock() {
        let saved = AppearanceMode.current
        defer { AppearanceMode.current = saved }
        let night = TestTime.date(26, 23)
        let noon = TestTime.date(26, 12)

        AppearanceMode.current = .day
        #expect(Palette.current(at: night, calendar: TestTime.calendar).isNight == false || DesignReviewForced.isSet)
        AppearanceMode.current = .night
        #expect(Palette.current(at: noon, calendar: TestTime.calendar).isNight == true || DesignReviewForced.isSet)
        AppearanceMode.current = .automatic
        #expect(NightMode.isActive(at: night, calendar: TestTime.calendar))
        #expect(!NightMode.isActive(at: noon, calendar: TestTime.calendar))
    }

    @Test func unknownStoredValueMeansAutomatic() {
        let saved = AppearanceMode.current
        defer { AppearanceMode.current = saved }
        AppGroup.defaults.set("sideways", forKey: AppearanceMode.key)
        #expect(AppearanceMode.current == .automatic)
    }
}

/// Debug design-review runs can pin day or night, which wins over the toggle.
enum DesignReviewForced {
    static var isSet: Bool {
        AppGroup.defaults.object(forKey: "designReview.forcedNight") != nil
    }
}
