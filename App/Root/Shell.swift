import Core
import Observation

/// The four top-level tabs. Nothing else is top-level.
enum AppTab: Hashable {
    case today, todo, progress, info
    /// The round Log button in the glass bar: selecting it logs itching instead of switching tabs.
    case logItchy
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
    /// Bowel movement or Mood from the More menu.
    var choosing: LogChoice?
    /// A flare getting "Add where".
    var addingWhere: LogEntry?
    /// Start Tonight (asks which child first when there's more than one).
    var startingTonight = false
    var pickingTonightChild = false
    /// Bumped when Tonight starts or ends, so rows showing it refresh.
    var tonightVersion = 0
    /// Last night's summary, from the morning Tonight card.
    var showingNight = false
}
