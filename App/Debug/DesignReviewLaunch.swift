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
/// sample data from Settings › Debug.
enum DesignReviewLaunch {
    static func apply() {
        if DesignReview.applyLaunchArgument() {
            WidgetCenter.shared.reloadAllTimelines()
        }
        if let kind = UserDefaults.standard.string(forKey: "designReviewSeed"), ["YES", "UNRATED", "EMPTY", "MONTHS", "TWO", "SAMPLE"].contains(kind) {
            UserDefaults.standard.set(true, forKey: OnboardingFlag.key)
            Task { await seed(kind) }
        }
    }

    private static func seed(_ kind: String) async {
        guard let container = try? CaliCareModelContainer.shared() else { return }
        let children = ChildStore(modelContainer: container)
        guard (try? await children.activeChildren())?.isEmpty ?? false,
              let cal = try? await children.addChild(name: "Cal", colorTag: "sage")
        else { return }
        CurrentChildSetting().childID = cal.id
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
