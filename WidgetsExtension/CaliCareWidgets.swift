import Core
import SwiftUI
import WidgetKit

@main
struct CaliCareWidgets: WidgetBundle {
    init() {
        FontRegistry.registerAll()
    }

    var body: some Widget {
        PlaceholderWidget()
    }
}
