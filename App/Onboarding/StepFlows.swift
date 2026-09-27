import SwiftUI

/// The step-by-step screens for setup that happens outside the app. Assets are
/// named by feature and iOS version so they're easy to replace when iOS changes.
/// Tap spots are fractions of the screenshot, measured when it was captured.
enum StepFlows {
    /// Captured in the iOS 27 simulator.
    static let widgetHome: [VisualStep] = [
        VisualStep(asset: "widgetHome_ios27_step1", sentence: "Touch and hold an empty area of your Home Screen until the apps jiggle.", tap: UnitPoint(x: 0.500, y: 0.680)),
        VisualStep(asset: "widgetHome_ios27_step2", sentence: "Tap Edit in the top-left corner.", tap: UnitPoint(x: 0.172, y: 0.038)),
        VisualStep(asset: "widgetHome_ios27_step3", sentence: "Tap Add Widget.", tap: UnitPoint(x: 0.391, y: 0.106)),
        VisualStep(asset: "widgetHome_ios27_step4", sentence: "Search for Cali Care and tap it.", tap: UnitPoint(x: 0.500, y: 0.538)),
        VisualStep(asset: "widgetHome_ios27_step5", sentence: "Swipe to pick a size, then tap Add Widget.", tap: UnitPoint(x: 0.500, y: 0.905)),
        VisualStep(asset: "widgetHome_ios27_step6", sentence: "Tap the checkmark in the top-right corner.", tap: UnitPoint(x: 0.828, y: 0.038)),
    ]

    /// Captured in the iOS 27 simulator. On iOS 27, Customize opens the Lock
    /// Screen editor directly; there's no separate "Lock Screen" choice.
    static let widgetLock: [VisualStep] = [
        VisualStep(asset: "widgetLock_ios27_step1", sentence: "Touch and hold your Lock Screen.", tap: UnitPoint(x: 0.500, y: 0.450)),
        VisualStep(asset: "widgetLock_ios27_step2", sentence: "Tap Customize.", tap: UnitPoint(x: 0.500, y: 0.930)),
        VisualStep(asset: "widgetLock_ios27_step3", sentence: "Tap the widget area under the clock.", tap: UnitPoint(x: 0.500, y: 0.788)),
        VisualStep(asset: "widgetLock_ios27_step4", sentence: "Tap Cali Care in the list.", tap: UnitPoint(x: 0.500, y: 0.724)),
        VisualStep(asset: "widgetLock_ios27_step5", sentence: "Tap Itchy to add it. Swipe for Last night.", tap: UnitPoint(x: 0.500, y: 0.698)),
        VisualStep(asset: "widgetLock_ios27_step6", sentence: "Tap Done.", tap: UnitPoint(x: 0.818, y: 0.038)),
    ]

    /// Recorded on a real iPhone. Placeholders until then.
    static let actionButton: [VisualStep] = [
        VisualStep(asset: "actionButton_ios27_step1", sentence: "Open Settings and tap Action Button."),
        VisualStep(asset: "actionButton_ios27_step2", sentence: "Swipe to Controls."),
        VisualStep(asset: "actionButton_ios27_step3", sentence: "Swipe to Controls, then pick Log Itchy."),
    ]

    /// Recorded on a real iPhone. Placeholders until then.
    static let controlCenter: [VisualStep] = [
        VisualStep(asset: "controlCenter_ios27_step1", sentence: "Swipe down from the top-right corner."),
        VisualStep(asset: "controlCenter_ios27_step2", sentence: "Touch and hold an empty area."),
        VisualStep(asset: "controlCenter_ios27_step3", sentence: "Tap Add a Control."),
        VisualStep(asset: "controlCenter_ios27_step4", sentence: "Search for Cali Care, tap Log Itchy, then tap an empty area to finish."),
    ]
}
