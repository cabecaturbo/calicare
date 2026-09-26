import Foundation
import SwiftData

/// Reads what the widgets show. Kept apart from WidgetKit so it can be tested.
public struct WidgetDataSource: Sendable {
    private let logs: LogStore
    private let children: ChildStore
    private let setting: CurrentChildSetting
    private let feedbackStore: WidgetFeedbackStore
    private let calendar: Calendar

    public init(
        container: ModelContainer,
        setting: CurrentChildSetting = CurrentChildSetting(),
        feedbackStore: WidgetFeedbackStore = WidgetFeedbackStore(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.logs = LogStore(modelContainer: container, calendar: calendar)
        self.children = ChildStore(modelContainer: container)
        self.setting = setting
        self.feedbackStore = feedbackStore
        self.calendar = calendar
    }

    /// Uses the shared App Group database.
    public static func live() throws -> WidgetDataSource {
        WidgetDataSource(container: try CaliCareModelContainer.shared())
    }

    /// The configured child if still active, otherwise the current child.
    public func child(for id: UUID?) async throws -> ChildInfo? {
        if let id, let match = try await children.activeChildren().first(where: { $0.id == id }) {
            return match
        }
        return try await children.currentChild(setting: setting)
    }

    /// Counts for the care day containing `date`, plus last night and the latest itch.
    public func snapshot(for child: ChildInfo?, at date: Date) async throws -> WidgetSnapshot {
        guard let child else { return .empty }
        let day = CareDay.containing(date, calendar: calendar)
        let previousDay = day.adding(days: -1, calendar: calendar)
        let today = DaySummary(day: day, events: try await logs.events(for: day, child: child.id), calendar: calendar)
        let previous = DaySummary(
            day: previousDay,
            events: try await logs.events(for: previousDay, child: child.id),
            calendar: calendar
        )
        return WidgetSnapshot(
            child: child,
            itchCount: today.itchEpisodes,
            bowelMovementCount: today.bowelMovementCount,
            routinesDone: today.routinesDone,
            lastNight: WidgetSnapshot.resolveLastNight(at: date, today: today, previous: previous, calendar: calendar),
            lastItch: try await logs.latest(.itchEpisode, child: child.id)?.timestamp
        )
    }

    /// The last widget tap for this child, if it's recent and hasn't been undone.
    public func feedback(for child: ChildInfo?, at date: Date) async throws -> WidgetFeedback? {
        guard let child, let feedback = feedbackStore.latest,
              feedback.childID == child.id,
              feedback.isShowing(at: date),
              try await logs.isLive(feedback.logID)
        else { return nil }
        return feedback
    }
}
