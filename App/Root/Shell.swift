import Core
import Observation

/// The four top-level tabs. Nothing else is top-level.
enum AppTab: Hashable {
    case today, todo, progress, plan
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
    /// Put Quick Log on the Lock Screen (asks which child first when there's more than one).
    var startingQuickLog = false
    var pickingQuickLogChild = false
    /// Bumped when the card is added or removed, so rows showing it refresh.
    var quickLogVersion = 0
    /// Last night's summary, from the card in the morning.
    var showingNight = false
}
