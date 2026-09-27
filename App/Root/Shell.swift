import Observation

/// The three top-level tabs. Nothing else is top-level.
enum AppTab: Hashable {
    case today, plan, progress
}

/// What the shell shows over every tab: which tab is up, and its sheets.
@MainActor
@Observable
final class Shell {
    var tab: AppTab = .today
    var showingSettings = false
    var showingAddChild = false
    var showingLog = false
    var showingNote = false
}
