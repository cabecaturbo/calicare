import Core
import Foundation
import Observation

/// The four top-level tabs. Nothing else is top-level.
enum AppTab: Hashable {
    /// Today, To do, How it's going, Care plan.
    case today, todo, progress, info
}

/// What the shell shows over every tab: which tab is up, and its sheets.
@MainActor
@Observable
final class Shell {
    var tab: AppTab = Shell.firstTab
    var showingSettings: Bool = {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "designReviewSettings")
        #else
        false
        #endif
    }()
    var showingAddChild = false
    var showingLog = false
    var showingNote = false
    /// "More" beside Itchy: Flare, Bowel movement, Mood, Note.
    var showingMore = false
    /// What was picked in More, run once its sheet has closed.
    var pendingMore: MoreSheet.Choice?
    /// Bowel movement or Mood from the More menu.
    var choosing: LogChoice?
    /// A flare getting "Add where".
    var addingWhere: LogEntry?

    /// Today, except in design review (`-designReviewTab todo|progress|info`).
    private static var firstTab: AppTab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "designReviewTab") {
        case "todo": return .todo
        case "progress": return .progress
        case "info": return .info
        default: return .today
        }
        #else
        return .today
        #endif
    }
}
