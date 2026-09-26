import AppIntents
import Core
import WidgetKit

/// Which child a widget logs for. Empty follows the current child.
struct SelectChildIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Child"
    static let description = IntentDescription("Pick which child this widget logs for.")

    @Parameter(title: "Child")
    var child: ChildEntity?

    init() {}
}
