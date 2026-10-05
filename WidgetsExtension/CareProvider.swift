import Core
import Foundation
import WidgetKit

struct CareEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// Set for about a minute after a widget tap, while the log is still there.
    let feedback: WidgetFeedback?

    var palette: Palette { Palette.current(at: date) }

    /// The child buttons log for, so taps match what the widget shows.
    var childEntity: ChildEntity? {
        snapshot.child.map { ChildEntity(id: $0.id, name: $0.name) }
    }

    static func sample(at date: Date) -> CareEntry {
        CareEntry(date: date, snapshot: .sample, feedback: nil)
    }
}

/// Builds entries for now, for when "Logged" ends, and for the 7 AM, 7 PM,
/// and 8 PM changes, so counts roll over and the night palette switches on time.
struct CareProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CareEntry {
        .sample(at: .now)
    }

    func snapshot(for configuration: SelectChildIntent, in context: Context) async -> CareEntry {
        if context.isPreview { return .sample(at: .now) }
        return await entries(childID: configuration.child?.id, now: .now).first ?? .sample(at: .now)
    }

    func timeline(for configuration: SelectChildIntent, in context: Context) async -> Timeline<CareEntry> {
        Timeline(entries: await entries(childID: configuration.child?.id, now: .now), policy: .atEnd)
    }

    private func entries(childID: UUID?, now: Date) async -> [CareEntry] {
        do {
            let source = try WidgetDataSource.live()
            let child = try await source.child(for: childID)
            let feedback = try await source.feedback(for: child, at: now)
            var entries: [CareEntry] = []
            for date in WidgetTimeline.dates(from: now, feedback: feedback) {
                let snapshot = try await source.snapshot(for: child, at: date)
                let showing = feedback?.isShowing(at: date) == true ? feedback : nil
                entries.append(CareEntry(date: date, snapshot: snapshot, feedback: showing))
            }
            return entries
        } catch {
            LockScreenDiagnostics.note("Widget timeline failed: \(error). Data available: \(LockScreenDiagnostics.protectedDataAvailable)")
            return [CareEntry(date: now, snapshot: .empty, feedback: nil)]
        }
    }
}
