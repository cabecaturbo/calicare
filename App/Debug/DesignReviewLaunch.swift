#if DEBUG
import Core
import WidgetKit

/// Debug builds only: lets design-review screenshots pin day or night.
enum DesignReviewLaunch {
    static func apply() {
        if DesignReview.applyLaunchArgument() {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
#endif
